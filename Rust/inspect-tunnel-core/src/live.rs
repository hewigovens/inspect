use crate::flow::FlowTracker;
use crate::logging::append_log;
use crate::model::{
    InspectTunnelCoreConfig, InspectTunnelCoreStats, PacketObservation, TransportProtocol,
};
use crate::packet::{infer_packet_direction, parse_packet, strip_utun_header};
use std::collections::HashSet;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};

const MAXIMUM_OBSERVATIONS: usize = 256;

#[derive(Clone, Debug, Hash, PartialEq, Eq)]
pub struct OutboundTcpConnectRequest {
    pub remote_host: String,
    pub remote_port: u16,
}

pub trait OutboundTcpConnector: Send + Sync + 'static {
    fn connect(&self, request: OutboundTcpConnectRequest);
}

#[derive(Default)]
pub struct NoopOutboundTcpConnector;

impl OutboundTcpConnector for NoopOutboundTcpConnector {
    fn connect(&self, _request: OutboundTcpConnectRequest) {}
}

#[cfg(not(target_os = "ios"))]
pub struct StdTcpConnector {
    connect_timeout: std::time::Duration,
}

#[cfg(not(target_os = "ios"))]
impl StdTcpConnector {
    pub fn new(connect_timeout: std::time::Duration) -> Self {
        Self { connect_timeout }
    }
}

#[cfg(not(target_os = "ios"))]
impl Default for StdTcpConnector {
    fn default() -> Self {
        Self::new(std::time::Duration::from_millis(750))
    }
}

#[cfg(not(target_os = "ios"))]
impl OutboundTcpConnector for StdTcpConnector {
    fn connect(&self, request: OutboundTcpConnectRequest) {
        let connect_timeout = self.connect_timeout;
        thread::spawn(move || {
            let address = format!("{}:{}", request.remote_host, request.remote_port);
            let Ok(mut socket_addresses) = address.to_socket_addrs() else {
                return;
            };
            let Some(socket_address) = socket_addresses.next() else {
                return;
            };
            let _ = std::net::TcpStream::connect_timeout(&socket_address, connect_timeout);
        });
    }
}

pub struct LiveEngine {
    stop_requested: Arc<AtomicBool>,
    stats: Arc<LiveStats>,
    observations: Arc<Mutex<Vec<PacketObservation>>>,
    worker_handle: Option<JoinHandle<()>>,
}

impl LiveEngine {
    pub fn start(
        tun_fd: i32,
        config: InspectTunnelCoreConfig,
        log_file: Option<PathBuf>,
        connector: Arc<dyn OutboundTcpConnector>,
    ) -> Result<Self, String> {
        let duplicated_fd = unsafe { libc::dup(tun_fd) };
        if duplicated_fd < 0 {
            return Err(format!(
                "failed to duplicate tun fd {tun_fd}: {}",
                std::io::Error::last_os_error()
            ));
        }

        let local_hosts = normalized_local_hosts(&config);
        let stop_requested = Arc::new(AtomicBool::new(false));
        let stats = Arc::new(LiveStats::default());
        let observations = Arc::new(Mutex::new(Vec::new()));

        append_log(
            log_file.as_deref(),
            "RustLive",
            &format!(
                "starting live loop tun_fd={} duplicated_fd={} local_hosts={}",
                tun_fd,
                duplicated_fd,
                local_hosts.iter().cloned().collect::<Vec<_>>().join(",")
            ),
        );

        let worker_handle = {
            let stop_requested = Arc::clone(&stop_requested);
            let stats = Arc::clone(&stats);
            let observations = Arc::clone(&observations);
            let log_file = log_file.clone();
            thread::Builder::new()
                .name("inspect-tunnel-live".to_string())
                .spawn(move || {
                    let owned_fd = unsafe { OwnedFd::from_raw_fd(duplicated_fd) };
                    let mut flow_tracker = FlowTracker::default();
                    let mut requested_connects = HashSet::new();
                    let mut read_buffer = vec![0u8; usize::from(config.mtu).max(2048) + 4];

                    append_log(
                        log_file.as_deref(),
                        "RustLive",
                        &format!("live loop thread started fd={}", owned_fd.as_raw_fd()),
                    );

                    loop {
                        if stop_requested.load(Ordering::Relaxed) {
                            break;
                        }

                        let mut pollfd = libc::pollfd {
                            fd: owned_fd.as_raw_fd(),
                            events: libc::POLLIN,
                            revents: 0,
                        };
                        let poll_result = unsafe { libc::poll(&mut pollfd, 1, 250) };
                        if poll_result < 0 {
                            let error = std::io::Error::last_os_error();
                            if error.kind() == std::io::ErrorKind::Interrupted {
                                continue;
                            }
                            append_log(
                                log_file.as_deref(),
                                "RustLive",
                                &format!("poll failed: {error}"),
                            );
                            break;
                        }
                        if poll_result == 0 || (pollfd.revents & libc::POLLIN) == 0 {
                            continue;
                        }

                        let read_count = unsafe {
                            libc::read(
                                owned_fd.as_raw_fd(),
                                read_buffer.as_mut_ptr().cast(),
                                read_buffer.len(),
                            )
                        };
                        if read_count < 0 {
                            let error = std::io::Error::last_os_error();
                            match error.kind() {
                                std::io::ErrorKind::Interrupted
                                | std::io::ErrorKind::WouldBlock => {
                                    continue;
                                }
                                _ => {
                                    append_log(
                                        log_file.as_deref(),
                                        "RustLive",
                                        &format!("read failed: {error}"),
                                    );
                                    break;
                                }
                            }
                        }
                        if read_count == 0 {
                            continue;
                        }

                        let packet = strip_utun_header(&read_buffer[..read_count as usize]);
                        let Some(direction) = infer_packet_direction(packet, &local_hosts) else {
                            continue;
                        };

                        let packet_length = u64::try_from(packet.len()).unwrap_or_default();
                        match direction {
                            crate::model::PacketDirection::Outbound => {
                                stats.tx_packets.fetch_add(1, Ordering::Relaxed);
                                stats.tx_bytes.fetch_add(packet_length, Ordering::Relaxed);
                            }
                            crate::model::PacketDirection::Inbound => {
                                stats.rx_packets.fetch_add(1, Ordering::Relaxed);
                                stats.rx_bytes.fetch_add(packet_length, Ordering::Relaxed);
                            }
                        }

                        let Some(parsed) = parse_packet(packet, direction) else {
                            continue;
                        };

                        if parsed.direction == crate::model::PacketDirection::Outbound
                            && parsed.transport == TransportProtocol::Tcp
                        {
                            if let Some(remote_port) = parsed.remote_port {
                                let request = OutboundTcpConnectRequest {
                                    remote_host: parsed.remote_host.clone(),
                                    remote_port,
                                };
                                if requested_connects.insert(request.clone()) {
                                    append_log(
                                        log_file.as_deref(),
                                        "RustLive",
                                        &format!(
                                            "requesting outbound TCP connect {}:{}",
                                            request.remote_host, request.remote_port
                                        ),
                                    );
                                    connector.connect(request);
                                }
                            }
                        }

                        let observation = flow_tracker.observe(&parsed);
                        if observation.server_name.is_some()
                            || observation.captured_certificate_chain_der_hex.is_some()
                        {
                            append_log(
                                log_file.as_deref(),
                                "RustLive",
                                &format!(
                                    "observed direction={} remote={} port={} sni={} certs={}",
                                    observation.direction.label(),
                                    observation.remote_host,
                                    observation
                                        .remote_port
                                        .map(|value| value.to_string())
                                        .unwrap_or_else(|| "nil".to_string()),
                                    observation.server_name.as_deref().unwrap_or("nil"),
                                    observation
                                        .captured_certificate_chain_der_hex
                                        .as_ref()
                                        .map(|items| items.len().to_string())
                                        .unwrap_or_else(|| "0".to_string())
                                ),
                            );
                        }

                        if let Ok(mut stored_observations) = observations.lock() {
                            stored_observations.push(observation);
                            if stored_observations.len() > MAXIMUM_OBSERVATIONS {
                                let excess = stored_observations.len() - MAXIMUM_OBSERVATIONS;
                                stored_observations.drain(..excess);
                            }
                        }
                    }

                    append_log(log_file.as_deref(), "RustLive", "live loop thread stopped");
                })
                .map_err(|error| format!("failed to spawn live loop thread: {error}"))?
        };

        Ok(Self {
            stop_requested,
            stats,
            observations,
            worker_handle: Some(worker_handle),
        })
    }

    pub fn stop(&mut self) {
        self.stop_requested.store(true, Ordering::Relaxed);
        if let Some(worker_handle) = self.worker_handle.take() {
            let _ = worker_handle.join();
        }
    }

    pub fn stats(&self) -> InspectTunnelCoreStats {
        self.stats.snapshot()
    }

    pub fn observations(&self) -> Vec<PacketObservation> {
        self.observations
            .lock()
            .map(|items| items.clone())
            .unwrap_or_default()
    }
}

impl Drop for LiveEngine {
    fn drop(&mut self) {
        self.stop();
    }
}

#[derive(Default)]
struct LiveStats {
    tx_packets: AtomicU64,
    tx_bytes: AtomicU64,
    rx_packets: AtomicU64,
    rx_bytes: AtomicU64,
}

impl LiveStats {
    fn snapshot(&self) -> InspectTunnelCoreStats {
        InspectTunnelCoreStats {
            tx_packets: self.tx_packets.load(Ordering::Relaxed),
            tx_bytes: self.tx_bytes.load(Ordering::Relaxed),
            rx_packets: self.rx_packets.load(Ordering::Relaxed),
            rx_bytes: self.rx_bytes.load(Ordering::Relaxed),
        }
    }
}

fn normalized_local_hosts(config: &InspectTunnelCoreConfig) -> HashSet<String> {
    [
        config.ipv4_address.as_str(),
        config.ipv6_address.as_str(),
        config.dns_address.as_str(),
    ]
    .into_iter()
    .map(canonicalize_host)
    .collect()
}

fn canonicalize_host(host: &str) -> String {
    host.parse::<std::net::IpAddr>()
        .map(|address| address.to_string())
        .unwrap_or_else(|_| host.trim().to_lowercase())
}

#[cfg(not(target_os = "ios"))]
use std::net::ToSocketAddrs;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{InspectTunnelCoreConfig, PacketDirection};
    use crate::packet::{build_tls_client_hello_packet, summarize_packet};
    use std::os::fd::RawFd;
    use std::time::{Duration, Instant};

    #[derive(Default)]
    struct RecordingConnector {
        requests: Mutex<Vec<OutboundTcpConnectRequest>>,
    }

    impl OutboundTcpConnector for RecordingConnector {
        fn connect(&self, request: OutboundTcpConnectRequest) {
            self.requests.lock().expect("requests lock").push(request);
        }
    }

    #[test]
    fn live_loop_reads_packets_and_requests_outbound_tcp_connect() {
        let (read_fd, write_fd) = pipe_fds();
        let connector = Arc::new(RecordingConnector::default());
        let config = InspectTunnelCoreConfig {
            ipv4_address: "198.18.0.1".to_string(),
            ipv6_address: "fd00::1".to_string(),
            dns_address: "198.18.0.2".to_string(),
            fake_ip_range: "198.18.0.0/16".to_string(),
            mtu: 1500,
            monitor_enabled: true,
        };

        let mut live_engine =
            LiveEngine::start(read_fd, config, None, connector.clone()).expect("start live engine");
        let packet =
            build_tls_client_hello_packet("198.18.0.1", "93.184.216.34", 443, "example.com")
                .expect("build packet");
        write_all(write_fd, &packet);

        wait_for(
            || live_engine.stats().tx_packets >= 1,
            Duration::from_secs(1),
        );
        wait_for(
            || connector.requests.lock().expect("requests").len() == 1,
            Duration::from_secs(1),
        );
        wait_for(
            || live_engine.observations().len() == 1,
            Duration::from_secs(1),
        );

        let observations = live_engine.observations();
        assert_eq!(observations.len(), 1);
        assert_eq!(observations[0].server_name.as_deref(), Some("example.com"));
        assert_eq!(
            connector.requests.lock().expect("requests")[0],
            OutboundTcpConnectRequest {
                remote_host: "93.184.216.34".to_string(),
                remote_port: 443,
            }
        );

        live_engine.stop();
        close_fd(write_fd);
    }

    #[test]
    fn strips_utun_header_before_observation() {
        let packet =
            build_tls_client_hello_packet("198.18.0.1", "93.184.216.34", 443, "example.com")
                .expect("build packet");
        let mut framed_packet = Vec::with_capacity(packet.len() + 4);
        framed_packet.extend_from_slice(&(libc::AF_INET as u32).to_ne_bytes());
        framed_packet.extend_from_slice(&packet);

        let stripped = strip_utun_header(&framed_packet);
        let observation =
            summarize_packet(stripped, PacketDirection::Outbound).expect("observation");
        assert_eq!(observation.server_name.as_deref(), Some("example.com"));
    }

    fn wait_for(predicate: impl Fn() -> bool, timeout: Duration) {
        let start = Instant::now();
        while start.elapsed() < timeout {
            if predicate() {
                return;
            }
            thread::sleep(Duration::from_millis(20));
        }

        panic!("timed out waiting for predicate");
    }

    fn pipe_fds() -> (RawFd, RawFd) {
        let mut fds = [0; 2];
        let result = unsafe { libc::pipe(fds.as_mut_ptr()) };
        assert_eq!(result, 0, "pipe creation failed");
        (fds[0], fds[1])
    }

    fn write_all(fd: RawFd, bytes: &[u8]) {
        let mut written = 0usize;
        while written < bytes.len() {
            let result =
                unsafe { libc::write(fd, bytes[written..].as_ptr().cast(), bytes.len() - written) };
            assert!(result >= 0, "pipe write failed");
            written += usize::try_from(result).expect("write size");
        }
    }

    fn close_fd(fd: RawFd) {
        let _ = unsafe { libc::close(fd) };
    }
}
