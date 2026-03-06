use crate::flow::FlowTracker;
use crate::logging::append_log;
use crate::model::{
    InspectTunnelCoreConfig, InspectTunnelCoreStats, PacketObservation, ReplayResult,
    ReplayScenario,
};
use crate::packet::{materialize_replay_packets, parse_packet};
use crate::tun2proxy_live::Tun2ProxyLiveEngine;
use std::path::{Path, PathBuf};

pub const CORE_VERSION: &str = "inspect-tunnel-core/0.2.0-dev";

#[derive(Default)]
pub struct InspectTunnelCore {
    tun_fd: Option<i32>,
    log_file: Option<PathBuf>,
    started: bool,
    config: Option<InspectTunnelCoreConfig>,
    stats: InspectTunnelCoreStats,
    flow_tracker: FlowTracker,
    live_engine: Option<Tun2ProxyLiveEngine>,
}

impl InspectTunnelCore {
    pub fn set_log_file_path(&mut self, path: impl Into<PathBuf>) -> Result<(), String> {
        let path = path.into();
        if path.as_os_str().is_empty() {
            return Err("log file path must not be empty".to_string());
        }

        self.log_file = Some(path.clone());
        self.write_log(
            "RustCore",
            &format!("configured log file at {}", path.display()),
        );
        Ok(())
    }

    pub fn set_tun_fd(&mut self, fd: i32) -> Result<(), String> {
        if fd < 0 {
            return Err(format!("invalid tun fd {fd}"));
        }

        self.tun_fd = Some(fd);
        self.write_log("RustCore", &format!("configured tun fd {fd}"));
        Ok(())
    }

    pub fn start(&mut self, config: InspectTunnelCoreConfig) -> Result<(), String> {
        if self.started {
            return Err("core already started".to_string());
        }

        let tun_fd = self
            .tun_fd
            .ok_or_else(|| "tun fd must be configured before start".to_string())?;

        self.write_log(
            "RustCore",
            &format!(
                "starting core tun_fd={} ipv4={} ipv6={} dns={} fake_ip_range={} mtu={} monitor_enabled={}",
                tun_fd,
                config.ipv4_address,
                config.ipv6_address,
                config.dns_address,
                config.fake_ip_range,
                config.mtu,
                config.monitor_enabled
            ),
        );

        self.started = true;
        self.config = Some(config);
        self.stats = InspectTunnelCoreStats::default();
        self.flow_tracker.clear();
        Ok(())
    }

    pub fn start_live_loop(&mut self) -> Result<(), String> {
        if !self.started {
            return Err("core must be started before live loop".to_string());
        }
        if self.live_engine.is_some() {
            return Err("live loop already started".to_string());
        }

        let tun_fd = self
            .tun_fd
            .ok_or_else(|| "tun fd must be configured before starting live loop".to_string())?;
        let config = self
            .config
            .clone()
            .ok_or_else(|| "config must be present before starting live loop".to_string())?;

        let live_engine = Tun2ProxyLiveEngine::start(tun_fd, config, self.log_file.clone())?;
        self.write_log("RustCore", "live loop started");
        self.live_engine = Some(live_engine);
        Ok(())
    }

    pub fn stop(&mut self) {
        if let Some(mut live_engine) = self.live_engine.take() {
            live_engine.stop();
        }
        if self.started {
            self.write_log("RustCore", "stopping core");
        }

        self.started = false;
        self.tun_fd = None;
        self.config = None;
        self.stats = InspectTunnelCoreStats::default();
        self.flow_tracker.clear();
    }

    pub fn stats(&self) -> InspectTunnelCoreStats {
        self.live_engine
            .as_ref()
            .map(Tun2ProxyLiveEngine::stats)
            .unwrap_or(self.stats)
    }

    pub fn drain_live_observations(&self) -> Vec<PacketObservation> {
        self.live_engine
            .as_ref()
            .map(Tun2ProxyLiveEngine::observations)
            .unwrap_or_default()
    }

    pub fn ingest_packet(
        &mut self,
        packet: &[u8],
        direction: crate::model::PacketDirection,
    ) -> Option<PacketObservation> {
        if !self.started {
            return None;
        }

        let packet_length = u64::try_from(packet.len()).ok()?;
        match direction {
            crate::model::PacketDirection::Outbound => {
                self.stats.tx_packets += 1;
                self.stats.tx_bytes += packet_length;
            }
            crate::model::PacketDirection::Inbound => {
                self.stats.rx_packets += 1;
                self.stats.rx_bytes += packet_length;
            }
        }

        let parsed = parse_packet(packet, direction)?;
        let observation = self.flow_tracker.observe(&parsed);
        self.write_log(
            "RustReplay",
            &format!(
                "observed direction={} transport={:?} remote_host={} remote_port={} sni={} certs={}",
                direction.label(),
                observation.transport,
                observation.remote_host,
                observation
                    .remote_port
                    .map(|value| value.to_string())
                    .unwrap_or_else(|| "nil".to_string()),
                observation.server_name.as_deref().unwrap_or("nil"),
                observation
                    .captured_certificate_chain_der_hex
                    .as_ref()
                    .map(|certificates| certificates.len().to_string())
                    .unwrap_or_else(|| "0".to_string())
            ),
        );
        Some(observation)
    }

    pub fn run_replay(&mut self, scenario: ReplayScenario) -> Result<ReplayResult, String> {
        self.run_replay_with_base_dir(scenario, None)
    }

    pub fn run_replay_with_base_dir(
        &mut self,
        scenario: ReplayScenario,
        base_dir: Option<&Path>,
    ) -> Result<ReplayResult, String> {
        if let Some(path) = scenario.log_file.as_deref() {
            self.set_log_file_path(path)?;
        }
        self.set_tun_fd(scenario.tun_fd.unwrap_or(5))?;
        self.start(scenario.config.clone())?;

        let mut observations = Vec::new();
        let mut packet_count = 0usize;
        for (index, replay_packet) in scenario.packets.iter().enumerate() {
            if let Some(note) = replay_packet.note() {
                self.write_log("RustReplay", &format!("packet[{index}] note={note}"));
            }

            let packets = materialize_replay_packets(replay_packet, base_dir)?;
            for packet in packets {
                packet_count += 1;
                if let Some(observation) = self.ingest_packet(&packet.bytes, packet.direction) {
                    observations.push(observation);
                }
            }
        }

        let stats = self.stats();
        let result = ReplayResult {
            version: CORE_VERSION.to_string(),
            packet_count,
            observations,
            stats,
            log_file: self
                .log_file
                .as_ref()
                .map(|path| path.display().to_string()),
        };

        self.stop();
        Ok(result)
    }

    pub fn log_file_path(&self) -> Option<&Path> {
        self.log_file.as_deref()
    }

    fn write_log(&self, scope: &str, message: &str) {
        append_log(self.log_file.as_deref(), scope, message);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{InspectTunnelCoreConfig, PacketDirection, ReplayPacket, ReplayScenario};
    use crate::packet::build_tls_client_hello_packet;
    use std::path::Path;
    use tempfile::tempdir;

    fn sample_config() -> InspectTunnelCoreConfig {
        InspectTunnelCoreConfig {
            ipv4_address: "198.18.0.1".to_string(),
            ipv6_address: "fd00::1".to_string(),
            dns_address: "198.18.0.2".to_string(),
            fake_ip_range: "198.18.0.0/16".to_string(),
            mtu: 1500,
            monitor_enabled: true,
        }
    }

    #[test]
    fn replay_counts_packets_and_extracts_sni() {
        let mut core = InspectTunnelCore::default();
        let replay = ReplayScenario {
            tun_fd: Some(5),
            log_file: None,
            config: sample_config(),
            packets: vec![ReplayPacket::TlsClientHello {
                direction: PacketDirection::Outbound,
                server_name: "example.com".to_string(),
                remote_host: "93.184.216.34".to_string(),
                remote_port: 443,
                source_host: Some("10.0.0.2".to_string()),
                note: Some("sample fixture".to_string()),
            }],
        };

        let result = core.run_replay(replay).expect("run replay");
        assert_eq!(result.packet_count, 1);
        assert_eq!(result.stats.tx_packets, 1);
        assert_eq!(result.stats.rx_packets, 0);
        assert_eq!(result.observations.len(), 1);
        assert_eq!(
            result.observations[0].server_name.as_deref(),
            Some("example.com")
        );
        assert!(
            result.observations[0]
                .captured_certificate_chain_der_hex
                .is_none()
        );
    }

    #[test]
    fn replay_reassembles_fragmented_handshake() {
        let mut core = InspectTunnelCore::default();
        let replay = ReplayScenario {
            tun_fd: Some(5),
            log_file: None,
            config: sample_config(),
            packets: vec![
                ReplayPacket::TlsClientHelloFragments {
                    direction: PacketDirection::Outbound,
                    server_name: "example.com".to_string(),
                    remote_host: "93.184.216.34".to_string(),
                    remote_port: 443,
                    source_host: Some("10.0.0.2".to_string()),
                    fragment_sizes: vec![20, 15],
                    note: None,
                },
                ReplayPacket::TlsServerCertificateFragments {
                    direction: PacketDirection::Inbound,
                    remote_host: "93.184.216.34".to_string(),
                    remote_port: 443,
                    certificate_files: vec!["../certs/mac_dev.cer".to_string()],
                    source_host: Some("10.0.0.2".to_string()),
                    fragment_sizes: vec![40, 200],
                    note: None,
                },
            ],
        };

        let base_dir =
            Path::new("/Users/hewig/workspace/h/Inspect/Rust/inspect-tunnel-core/fixtures/replay");
        let result = core
            .run_replay_with_base_dir(replay, Some(base_dir))
            .expect("run replay");

        assert!(result.packet_count > 2);
        assert!(result.stats.tx_packets >= 1);
        assert!(result.stats.rx_packets >= 1);

        let saw_sni = result
            .observations
            .iter()
            .any(|observation| observation.server_name.as_deref() == Some("example.com"));
        assert!(saw_sni);

        let saw_cert = result.observations.iter().any(|observation| {
            observation
                .captured_certificate_chain_der_hex
                .as_ref()
                .is_some_and(|certificates| !certificates.is_empty())
        });
        assert!(saw_cert);
    }

    #[test]
    fn replay_reads_packets_from_pcap_file() {
        let mut core = InspectTunnelCore::default();
        let temp_dir = tempdir().expect("tempdir");
        let packet = build_tls_client_hello_packet("10.0.0.2", "93.184.216.34", 443, "example.com")
            .expect("build packet");
        let pcap_path = temp_dir.path().join("sample.pcap");
        std::fs::write(&pcap_path, build_pcap(101, &[packet])).expect("write pcap");

        let replay = ReplayScenario {
            tun_fd: Some(5),
            log_file: None,
            config: sample_config(),
            packets: vec![ReplayPacket::PcapFile {
                direction: PacketDirection::Outbound,
                path: "sample.pcap".to_string(),
                note: None,
            }],
        };

        let result = core
            .run_replay_with_base_dir(replay, Some(temp_dir.path()))
            .expect("run replay");
        assert_eq!(result.packet_count, 1);
        assert_eq!(
            result.observations[0].server_name.as_deref(),
            Some("example.com")
        );
    }

    fn build_pcap(link_type: u32, packets: &[Vec<u8>]) -> Vec<u8> {
        let mut bytes = Vec::new();
        bytes.extend_from_slice(&[0xd4, 0xc3, 0xb2, 0xa1]);
        bytes.extend_from_slice(&2u16.to_le_bytes());
        bytes.extend_from_slice(&4u16.to_le_bytes());
        bytes.extend_from_slice(&0i32.to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes());
        bytes.extend_from_slice(&65_535u32.to_le_bytes());
        bytes.extend_from_slice(&link_type.to_le_bytes());

        for packet in packets {
            let length = u32::try_from(packet.len()).expect("length");
            bytes.extend_from_slice(&0u32.to_le_bytes());
            bytes.extend_from_slice(&0u32.to_le_bytes());
            bytes.extend_from_slice(&length.to_le_bytes());
            bytes.extend_from_slice(&length.to_le_bytes());
            bytes.extend_from_slice(packet);
        }

        bytes
    }

}
