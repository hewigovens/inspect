use crate::flow::FlowTracker;
use crate::model::{InspectTunnelCoreStats, PacketDirection, PacketObservation, TransportProtocol};
use crate::packet::ParsedPacket;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};
use tun2proxy::observer::{ObservedDirection, ObservedSession, SessionEvent, SessionObserver};

pub struct Tun2ProxySessionObserverAdapter {
    flow_tracker: Mutex<FlowTracker>,
    observations: Mutex<Vec<PacketObservation>>,
    tx_packets: AtomicU64,
    tx_bytes: AtomicU64,
    rx_packets: AtomicU64,
    rx_bytes: AtomicU64,
}

impl Tun2ProxySessionObserverAdapter {
    pub fn new() -> Self {
        Self {
            flow_tracker: Mutex::new(FlowTracker::default()),
            observations: Mutex::new(Vec::new()),
            tx_packets: AtomicU64::new(0),
            tx_bytes: AtomicU64::new(0),
            rx_packets: AtomicU64::new(0),
            rx_bytes: AtomicU64::new(0),
        }
    }

    pub fn take_observations(&self) -> Vec<PacketObservation> {
        let mut observations = self
            .observations
            .lock()
            .expect("observations lock poisoned");
        std::mem::take(&mut *observations)
    }

    pub fn latest_observation(&self) -> Option<PacketObservation> {
        self.observations
            .lock()
            .expect("observations lock poisoned")
            .last()
            .cloned()
    }

    pub fn stats(&self) -> InspectTunnelCoreStats {
        InspectTunnelCoreStats {
            tx_packets: self.tx_packets.load(Ordering::Relaxed),
            tx_bytes: self.tx_bytes.load(Ordering::Relaxed),
            rx_packets: self.rx_packets.load(Ordering::Relaxed),
            rx_bytes: self.rx_bytes.load(Ordering::Relaxed),
        }
    }
}

impl Default for Tun2ProxySessionObserverAdapter {
    fn default() -> Self {
        Self::new()
    }
}

impl SessionObserver for Tun2ProxySessionObserverAdapter {
    fn on_event(&self, event: SessionEvent) {
        let SessionEvent::Data {
            session,
            direction,
            data,
        } = event
        else {
            return;
        };

        let parsed = parsed_packet_from_session(&session, direction, data);
        let packet_length = u64::try_from(parsed.packet_bytes).unwrap_or_default();
        match direction {
            ObservedDirection::ClientToServer => {
                self.tx_packets.fetch_add(1, Ordering::Relaxed);
                self.tx_bytes.fetch_add(packet_length, Ordering::Relaxed);
            }
            ObservedDirection::ServerToClient => {
                self.rx_packets.fetch_add(1, Ordering::Relaxed);
                self.rx_bytes.fetch_add(packet_length, Ordering::Relaxed);
            }
        }
        let observation = self
            .flow_tracker
            .lock()
            .expect("flow tracker lock poisoned")
            .observe(&parsed);
        self.observations
            .lock()
            .expect("observations lock poisoned")
            .push(observation);
    }
}

fn parsed_packet_from_session(
    session: &ObservedSession,
    direction: ObservedDirection,
    data: Vec<u8>,
) -> ParsedPacket {
    let (packet_direction, source, destination) = match direction {
        ObservedDirection::ClientToServer => (
            PacketDirection::Outbound,
            session.source,
            session.destination,
        ),
        ObservedDirection::ServerToClient => (
            PacketDirection::Inbound,
            session.destination,
            session.source,
        ),
    };

    ParsedPacket {
        direction: packet_direction,
        transport: TransportProtocol::Tcp,
        source_host: source.ip().to_string(),
        destination_host: destination.ip().to_string(),
        source_port: Some(source.port()),
        destination_port: Some(destination.port()),
        local_host: session.source.ip().to_string(),
        remote_host: session.destination.ip().to_string(),
        local_port: Some(session.source.port()),
        remote_port: Some(session.destination.port()),
        tcp_payload: Some(data.clone()),
        packet_bytes: data.len(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::packet::{
        build_tls_client_hello_packet, build_tls_server_certificate_packet, parse_packet,
    };

    #[test]
    fn extracts_sni_from_tun2proxy_client_to_server_data() {
        let adapter = Tun2ProxySessionObserverAdapter::new();
        let packet = build_tls_client_hello_packet("10.0.0.2", "93.184.216.34", 443, "example.com")
            .expect("build packet");
        let parsed_packet =
            parse_packet(&packet, PacketDirection::Outbound).expect("parsed packet");
        let payload = parsed_packet.tcp_payload.expect("tcp payload");

        adapter.on_event(SessionEvent::Data {
            session: ObservedSession::tcp(
                "10.0.0.2:49512".parse().expect("source"),
                "93.184.216.34:443".parse().expect("destination"),
                Some("example.com".to_string()),
            ),
            direction: ObservedDirection::ClientToServer,
            data: payload,
        });

        assert_eq!(
            adapter
                .latest_observation()
                .and_then(|item| item.server_name),
            Some("example.com".to_string())
        );
    }

    #[test]
    fn extracts_certificates_from_tun2proxy_server_to_client_data() {
        let adapter = Tun2ProxySessionObserverAdapter::new();
        let certificate = vec![0x30, 0x03, 0x02, 0x01, 0x05];
        let packet = build_tls_server_certificate_packet(
            "93.184.216.34",
            "10.0.0.2",
            443,
            &[certificate.clone()],
        )
        .expect("build packet");
        let parsed_packet = parse_packet(&packet, PacketDirection::Inbound).expect("parsed packet");
        let payload = parsed_packet.tcp_payload.expect("tcp payload");

        adapter.on_event(SessionEvent::Data {
            session: ObservedSession::tcp(
                "10.0.0.2:49512".parse().expect("source"),
                "93.184.216.34:443".parse().expect("destination"),
                Some("example.com".to_string()),
            ),
            direction: ObservedDirection::ServerToClient,
            data: payload,
        });

        assert_eq!(
            adapter
                .latest_observation()
                .and_then(|item| item.captured_certificate_chain_der_hex),
            Some(vec![hex::encode(certificate)])
        );
    }
}
