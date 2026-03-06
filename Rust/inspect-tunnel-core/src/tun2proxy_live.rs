use crate::logging::{append_log, configure_rust_logger};
use crate::model::{InspectTunnelCoreConfig, InspectTunnelCoreStats, PacketObservation};
use crate::packet::strip_utun_header;
use crate::tun2proxy_observer::Tun2ProxySessionObserverAdapter;
use std::io;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::pin::Pin;
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::Arc;
use std::task::{Context, Poll};
use std::thread::{self, JoinHandle};
use tokio::io::unix::AsyncFd;
use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};
use tun2proxy::{ArgDns, ArgProxy, ArgVerbosity, Args, CancellationToken, run, set_session_observer};

pub struct Tun2ProxyLiveEngine {
    shutdown_token: CancellationToken,
    observer: Arc<Tun2ProxySessionObserverAdapter>,
    worker_handle: Option<JoinHandle<()>>,
}

impl Tun2ProxyLiveEngine {
    pub fn start(
        tun_fd: i32,
        config: InspectTunnelCoreConfig,
        log_file: Option<PathBuf>,
    ) -> Result<Self, String> {
        let observer = Arc::new(Tun2ProxySessionObserverAdapter::new());
        set_session_observer(Some(observer.clone()));

        let shutdown_token = CancellationToken::new();
        let worker_shutdown = shutdown_token.clone();
        let args = build_args(&config)?;
        let mtu = config.mtu;
        configure_rust_logger(log_file.clone(), args.verbosity.into());

        append_log(
            log_file.as_deref(),
            "RustTun2Proxy",
            &format!(
                "starting tun2proxy engine tun_fd={} mtu={} dns_strategy=direct dns_server={} fake_ip_range={}",
                tun_fd, mtu, config.dns_address, config.fake_ip_range
            ),
        );

        let worker_handle = thread::Builder::new()
            .name("inspect-tun2proxy-live".to_string())
            .spawn(move || {
                append_log(log_file.as_deref(), "RustTun2Proxy", "worker thread entered");
                let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    append_log(log_file.as_deref(), "RustTun2Proxy", "building tokio runtime");
                    let runtime = match tokio::runtime::Builder::new_current_thread()
                        .enable_all()
                        .build()
                    {
                        Ok(runtime) => runtime,
                        Err(error) => {
                            append_log(
                                log_file.as_deref(),
                                "RustTun2Proxy",
                                &format!("failed to create tokio runtime: {error}"),
                            );
                            return;
                        }
                    };
                    append_log(log_file.as_deref(), "RustTun2Proxy", "tokio runtime ready");

                    append_log(log_file.as_deref(), "RustTun2Proxy", "entering tun2proxy run loop");
                    let log_file_for_run = log_file.clone();
                    let result = runtime.block_on(async move {
                        append_log(
                            log_file_for_run.as_deref(),
                            "RustTun2Proxy",
                            &format!("creating raw utun wrapper from fd={tun_fd}"),
                        );
                        let device = RawUtunDevice::new(tun_fd, usize::from(mtu)).map_err(|error| {
                            io::Error::new(io::ErrorKind::Other, format!("raw utun wrapper: {error}"))
                        })?;
                        append_log(
                            log_file_for_run.as_deref(),
                            "RustTun2Proxy",
                            &format!("using raw utun wrapper duplicated_fd={}", device.as_raw_fd()),
                        );
                        run(device, mtu, args, worker_shutdown).await
                    });

                    match result {
                        Ok(session_count) => append_log(
                            log_file.as_deref(),
                            "RustTun2Proxy",
                            &format!(
                                "tun2proxy engine exited cleanly remaining_sessions={session_count}"
                            ),
                        ),
                        Err(error) => append_log(
                            log_file.as_deref(),
                            "RustTun2Proxy",
                            &format!("tun2proxy engine exited with error: {error}"),
                        ),
                    }
                }));

                if let Err(payload) = outcome {
                    let message = if let Some(text) = payload.downcast_ref::<&str>() {
                        (*text).to_string()
                    } else if let Some(text) = payload.downcast_ref::<String>() {
                        text.clone()
                    } else {
                        "unknown panic payload".to_string()
                    };
                    append_log(
                        log_file.as_deref(),
                        "RustTun2Proxy",
                        &format!("worker thread panicked: {message}"),
                    );
                }

                set_session_observer(None);
            })
            .map_err(|error| format!("failed to spawn tun2proxy worker: {error}"))?;

        Ok(Self {
            shutdown_token,
            observer,
            worker_handle: Some(worker_handle),
        })
    }

    pub fn stop(&mut self) {
        self.shutdown_token.cancel();
        if let Some(worker_handle) = self.worker_handle.take() {
            let _ = worker_handle.join();
        }
        set_session_observer(None);
    }

    pub fn stats(&self) -> InspectTunnelCoreStats {
        self.observer.stats()
    }

    pub fn observations(&self) -> Vec<PacketObservation> {
        self.observer.take_observations()
    }
}

impl Drop for Tun2ProxyLiveEngine {
    fn drop(&mut self) {
        self.stop();
    }
}

fn build_args(config: &InspectTunnelCoreConfig) -> Result<Args, String> {
    let mut args = Args::default();
    args.proxy = ArgProxy::try_from("none").map_err(|error| error.to_string())?;
    args.setup = false;
    args.dns = ArgDns::Direct;
    args.dns_addr = std::net::IpAddr::from_str(&config.dns_address)
        .map_err(|error| format!("invalid dns address '{}': {error}", config.dns_address))?;
    args.virtual_dns_pool = config
        .fake_ip_range
        .parse()
        .map_err(|error| format!("invalid fake IP range '{}': {error}", config.fake_ip_range))?;
    args.ipv6_enabled = true;
    args.verbosity = ArgVerbosity::Debug;
    Ok(args)
}

struct RawUtunDevice {
    fd: AsyncFd<OwnedFd>,
    read_buffer: Vec<u8>,
}

impl RawUtunDevice {
    fn new(tun_fd: i32, mtu: usize) -> Result<Self, String> {
        let duplicated_fd = unsafe { libc::dup(tun_fd) };
        if duplicated_fd < 0 {
            return Err(format!(
                "failed to duplicate tun fd {tun_fd}: {}",
                io::Error::last_os_error()
            ));
        }

        let current_flags = unsafe { libc::fcntl(duplicated_fd, libc::F_GETFL) };
        if current_flags < 0 {
            let error = io::Error::last_os_error();
            unsafe {
                libc::close(duplicated_fd);
            }
            return Err(format!("failed to read fd flags: {error}"));
        }

        let set_flags_result =
            unsafe { libc::fcntl(duplicated_fd, libc::F_SETFL, current_flags | libc::O_NONBLOCK) };
        if set_flags_result < 0 {
            let error = io::Error::last_os_error();
            unsafe {
                libc::close(duplicated_fd);
            }
            return Err(format!("failed to mark utun fd nonblocking: {error}"));
        }

        let owned_fd = unsafe { OwnedFd::from_raw_fd(duplicated_fd) };
        let async_fd = AsyncFd::new(owned_fd)
            .map_err(|error| format!("failed to wrap duplicated utun fd: {error}"))?;

        Ok(Self {
            fd: async_fd,
            read_buffer: vec![0u8; mtu.max(2048) + 4],
        })
    }
}

impl AsRawFd for RawUtunDevice {
    fn as_raw_fd(&self) -> std::os::fd::RawFd {
        self.fd.get_ref().as_raw_fd()
    }
}

impl AsyncRead for RawUtunDevice {
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<Result<(), io::Error>> {
        let this = self.get_mut();

        loop {
            let mut ready_guard = match this.fd.poll_read_ready_mut(cx) {
                Poll::Ready(Ok(guard)) => guard,
                Poll::Ready(Err(error)) => return Poll::Ready(Err(error)),
                Poll::Pending => return Poll::Pending,
            };

            let read_count = unsafe {
                libc::read(
                    ready_guard.get_inner().as_raw_fd(),
                    this.read_buffer.as_mut_ptr().cast(),
                    this.read_buffer.len(),
                )
            };
            if read_count < 0 {
                let error = io::Error::last_os_error();
                if error.kind() == io::ErrorKind::WouldBlock {
                    ready_guard.clear_ready();
                    continue;
                }
                return Poll::Ready(Err(error));
            }
            if read_count == 0 {
                ready_guard.clear_ready();
                continue;
            }

            let packet = strip_utun_header(&this.read_buffer[..read_count as usize]);
            if packet.len() > buf.remaining() {
                return Poll::Ready(Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    format!(
                        "read packet larger than destination buffer: packet={} buffer={}",
                        packet.len(),
                        buf.remaining()
                    ),
                )));
            }

            buf.put_slice(packet);
            return Poll::Ready(Ok(()));
        }
    }
}

impl AsyncWrite for RawUtunDevice {
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &[u8],
    ) -> Poll<Result<usize, io::Error>> {
        let this = self.get_mut();
        let framed_packet = match add_utun_header(buf) {
            Ok(packet) => packet,
            Err(error) => return Poll::Ready(Err(error)),
        };

        loop {
            let mut ready_guard = match this.fd.poll_write_ready_mut(cx) {
                Poll::Ready(Ok(guard)) => guard,
                Poll::Ready(Err(error)) => return Poll::Ready(Err(error)),
                Poll::Pending => return Poll::Pending,
            };

            let write_count = unsafe {
                libc::write(
                    ready_guard.get_inner().as_raw_fd(),
                    framed_packet.as_ptr().cast(),
                    framed_packet.len(),
                )
            };
            if write_count < 0 {
                let error = io::Error::last_os_error();
                if error.kind() == io::ErrorKind::WouldBlock {
                    ready_guard.clear_ready();
                    continue;
                }
                return Poll::Ready(Err(error));
            }

            if usize::try_from(write_count).unwrap_or_default() != framed_packet.len() {
                return Poll::Ready(Err(io::Error::new(
                    io::ErrorKind::WriteZero,
                    format!(
                        "short utun write: expected {} bytes, wrote {}",
                        framed_packet.len(),
                        write_count
                    ),
                )));
            }

            return Poll::Ready(Ok(buf.len()));
        }
    }

    fn poll_flush(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), io::Error>> {
        Poll::Ready(Ok(()))
    }

    fn poll_shutdown(self: Pin<&mut Self>, _cx: &mut Context<'_>) -> Poll<Result<(), io::Error>> {
        Poll::Ready(Ok(()))
    }
}

fn add_utun_header(packet: &[u8]) -> Result<Vec<u8>, io::Error> {
    let family = match packet.first().map(|value| value >> 4) {
        Some(4) => libc::AF_INET as u32,
        Some(6) => libc::AF_INET6 as u32,
        Some(version) => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!("unsupported IP version {version}"),
            ));
        }
        None => {
            return Err(io::Error::new(
                io::ErrorKind::UnexpectedEof,
                "cannot write empty utun packet",
            ));
        }
    };

    let mut framed = Vec::with_capacity(packet.len() + 4);
    framed.extend_from_slice(&family.to_ne_bytes());
    framed.extend_from_slice(packet);
    Ok(framed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::packet::{
        build_tls_client_hello_packet, build_tls_server_certificate_packet, parse_packet,
    };
    use once_cell::sync::Lazy;
    use std::io;
    use std::net::Ipv4Addr;
    use std::sync::Mutex;
    use std::time::Duration;
    use tokio::io::{AsyncReadExt, AsyncWriteExt, DuplexStream};
    use tokio::net::TcpListener;
    use tokio::time::{Instant, timeout};
    use tun2proxy::run;

    static TUN2PROXY_TEST_GUARD: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    #[test]
    fn build_args_uses_none_proxy_and_direct_dns() {
        let args = build_args(&InspectTunnelCoreConfig {
            ipv4_address: "198.18.0.1".to_string(),
            ipv6_address: "fd00::1".to_string(),
            dns_address: "1.1.1.1".to_string(),
            fake_ip_range: "198.19.0.0/16".to_string(),
            mtu: 1500,
            monitor_enabled: true,
        })
        .expect("build args");

        assert_eq!(args.proxy.to_string(), "none://0.0.0.0:0");
        assert_eq!(args.dns, ArgDns::Direct);
        assert_eq!(args.dns_addr.to_string(), "1.1.1.1");
        assert_eq!(args.setup, false);
        assert_eq!(args.tun_fd, None);
        assert_eq!(args.close_fd_on_drop, None);
    }

    #[tokio::test(flavor = "current_thread")]
    async fn tun2proxy_run_forwards_tcp_and_emits_tls_observations() {
        let _guard = TUN2PROXY_TEST_GUARD.lock().expect("test guard lock");

        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .expect("bind loopback listener");
        let server_port = listener.local_addr().expect("listener addr").port();

        let client_ip = "10.0.0.2";
        let server_ip = "127.0.0.1";
        let client_port = 49_512;
        let client_seq = 1000u32;

        let client_hello_packet =
            build_tls_client_hello_packet(client_ip, server_ip, server_port, "example.com")
                .expect("build client hello packet");
        let client_hello_payload = parse_packet(
            &client_hello_packet,
            crate::model::PacketDirection::Outbound,
        )
        .and_then(|packet| packet.tcp_payload)
        .expect("extract client hello payload");

        let certificate_der = vec![0x30, 0x03, 0x02, 0x01, 0x05];
        let server_certificate_packet = build_tls_server_certificate_packet(
            server_ip,
            client_ip,
            server_port,
            std::slice::from_ref(&certificate_der),
        )
        .expect("build server certificate packet");
        let server_certificate_payload = parse_packet(
            &server_certificate_packet,
            crate::model::PacketDirection::Inbound,
        )
        .and_then(|packet| packet.tcp_payload)
        .expect("extract certificate payload");

        let (device, mut host_side) = tokio::io::duplex(64 * 1024);
        let shutdown_token = CancellationToken::new();
        let observer = Arc::new(Tun2ProxySessionObserverAdapter::new());
        set_session_observer(Some(observer.clone()));

        let mut args = Args::default();
        args.proxy = ArgProxy::try_from("none").expect("parse no-proxy args");
        args.dns = ArgDns::Direct;
        args.setup = false;
        args.ipv6_enabled = false;
        args.verbosity = ArgVerbosity::Info;

        let run_shutdown = shutdown_token.clone();
        let run_task = tokio::spawn(async move { run(device, 1500, args, run_shutdown).await });

        let expected_client_hello = client_hello_payload.clone();
        let expected_server_certificate_payload = server_certificate_payload.clone();
        let server_task = tokio::spawn(async move {
            let (mut stream, _) = listener.accept().await.expect("accept tunneled connection");
            let mut received_client_hello = vec![0; expected_client_hello.len()];
            stream
                .read_exact(&mut received_client_hello)
                .await
                .expect("read client hello bytes");
            stream
                .write_all(&expected_server_certificate_payload)
                .await
                .expect("write certificate payload");
            received_client_hello
        });

        host_side
            .write_all(&build_ipv4_tcp_segment(
                client_ip,
                server_ip,
                client_port,
                server_port,
                client_seq,
                0,
                TCP_SYN,
                &[],
            ))
            .await
            .expect("write client SYN");

        let syn_ack_packet = timeout(Duration::from_secs(2), read_ip_packet(&mut host_side))
            .await
            .expect("read SYN-ACK timeout")
            .expect("read SYN-ACK packet");
        let syn_ack = parse_ipv4_tcp_segment(&syn_ack_packet).expect("parse SYN-ACK packet");
        assert_eq!(syn_ack.flags & (TCP_SYN | TCP_ACK), TCP_SYN | TCP_ACK);
        assert_eq!(syn_ack.ack, client_seq + 1);

        let client_ack_seq = client_seq + 1;
        let server_ack = syn_ack.seq + 1;

        host_side
            .write_all(&build_ipv4_tcp_segment(
                client_ip,
                server_ip,
                client_port,
                server_port,
                client_ack_seq,
                server_ack,
                TCP_ACK,
                &[],
            ))
            .await
            .expect("write client ACK");

        tokio::time::sleep(Duration::from_millis(100)).await;

        host_side
            .write_all(&build_ipv4_tcp_segment(
                client_ip,
                server_ip,
                client_port,
                server_port,
                client_ack_seq,
                server_ack,
                TCP_ACK | TCP_PSH,
                &client_hello_payload,
            ))
            .await
            .expect("write client hello data");

        let received_client_hello = timeout(Duration::from_secs(5), server_task)
            .await
            .expect("server task timeout")
            .expect("server task join");
        assert_eq!(received_client_hello, client_hello_payload);

        let mut server_data_seq = None;
        let deadline = Instant::now() + Duration::from_secs(2);
        while Instant::now() < deadline {
            let packet = timeout(Duration::from_millis(250), read_ip_packet(&mut host_side)).await;
            let Ok(Ok(packet)) = packet else {
                continue;
            };
            let segment = match parse_ipv4_tcp_segment(&packet) {
                Some(segment) => segment,
                None => continue,
            };

            if segment.payload.is_empty() {
                continue;
            }

            if segment.payload == server_certificate_payload {
                server_data_seq = Some(segment.seq);
                host_side
                    .write_all(&build_ipv4_tcp_segment(
                        client_ip,
                        server_ip,
                        client_port,
                        server_port,
                        client_ack_seq + u32::try_from(client_hello_payload.len()).unwrap_or(0),
                        segment.seq + u32::try_from(segment.payload.len()).unwrap_or(0),
                        TCP_ACK,
                        &[],
                    ))
                    .await
                    .expect("acknowledge server certificate payload");
                break;
            }
        }

        assert!(server_data_seq.is_some(), "expected tunneled server payload");

        let observations = wait_for_observations(&observer, 2, Duration::from_secs(2)).await;
        assert!(
            observations
                .iter()
                .any(|item| item.server_name.as_deref() == Some("example.com")),
            "expected SNI observation"
        );
        assert!(
            observations.iter().any(|item| {
                item.captured_certificate_chain_der_hex.as_ref()
                    == Some(&vec![hex::encode(&certificate_der)])
            }),
            "expected certificate-chain observation"
        );

        shutdown_token.cancel();
        drop(host_side);
        let _ = timeout(Duration::from_secs(2), run_task)
            .await
            .expect("tun2proxy shutdown timeout")
            .expect("tun2proxy run join");
        set_session_observer(None);
    }

    async fn wait_for_observations(
        observer: &Tun2ProxySessionObserverAdapter,
        minimum_count: usize,
        timeout_duration: Duration,
    ) -> Vec<PacketObservation> {
        let deadline = Instant::now() + timeout_duration;
        let mut collected = Vec::new();

        while Instant::now() < deadline {
            collected.extend(observer.take_observations());
            if collected.len() >= minimum_count {
                return collected;
            }
            tokio::time::sleep(Duration::from_millis(25)).await;
        }

        collected
    }

    async fn read_ip_packet(stream: &mut DuplexStream) -> io::Result<Vec<u8>> {
        let first_byte = stream.read_u8().await?;
        let version = first_byte >> 4;

        match version {
            4 => {
                let mut header_rest = [0u8; 19];
                stream.read_exact(&mut header_rest).await?;

                let total_length =
                    u16::from_be_bytes([header_rest[1], header_rest[2]]) as usize;
                if total_length < 20 {
                    return Err(io::Error::new(
                        io::ErrorKind::InvalidData,
                        "invalid IPv4 total length",
                    ));
                }

                let mut packet = Vec::with_capacity(total_length);
                packet.push(first_byte);
                packet.extend_from_slice(&header_rest);

                let remaining_length = total_length - 20;
                let mut payload = vec![0u8; remaining_length];
                stream.read_exact(&mut payload).await?;
                packet.extend_from_slice(&payload);
                Ok(packet)
            }
            _ => Err(io::Error::new(
                io::ErrorKind::InvalidData,
                format!("unsupported IP version {version}"),
            )),
        }
    }

    fn build_ipv4_tcp_segment(
        source_host: &str,
        destination_host: &str,
        source_port: u16,
        destination_port: u16,
        sequence_number: u32,
        acknowledgement_number: u32,
        flags: u8,
        payload: &[u8],
    ) -> Vec<u8> {
        let source_ip: Ipv4Addr = source_host.parse().expect("valid source IPv4");
        let destination_ip: Ipv4Addr = destination_host.parse().expect("valid destination IPv4");

        let tcp_header_length = 20usize;
        let total_length = 20usize + tcp_header_length + payload.len();
        let total_length_u16 = u16::try_from(total_length).expect("IPv4 packet length");

        let mut packet = vec![0u8; total_length];
        packet[0] = 0x45;
        packet[1] = 0x00;
        packet[2..4].copy_from_slice(&total_length_u16.to_be_bytes());
        packet[4..6].copy_from_slice(&0x0001u16.to_be_bytes());
        packet[6..8].copy_from_slice(&0x4000u16.to_be_bytes());
        packet[8] = 64;
        packet[9] = 6;
        packet[12..16].copy_from_slice(&source_ip.octets());
        packet[16..20].copy_from_slice(&destination_ip.octets());

        packet[20..22].copy_from_slice(&source_port.to_be_bytes());
        packet[22..24].copy_from_slice(&destination_port.to_be_bytes());
        packet[24..28].copy_from_slice(&sequence_number.to_be_bytes());
        packet[28..32].copy_from_slice(&acknowledgement_number.to_be_bytes());
        packet[32] = 0x50;
        packet[33] = flags;
        packet[34..36].copy_from_slice(&0xFFFFu16.to_be_bytes());
        packet[40..].copy_from_slice(payload);

        let ip_checksum = internet_checksum(&packet[..20]);
        packet[10..12].copy_from_slice(&ip_checksum.to_be_bytes());

        let tcp_checksum = tcp_checksum(source_ip, destination_ip, &packet[20..]);
        packet[36..38].copy_from_slice(&tcp_checksum.to_be_bytes());
        packet
    }

    fn parse_ipv4_tcp_segment(packet: &[u8]) -> Option<TestTcpSegment> {
        if packet.len() < 40 || (packet[0] >> 4) != 4 {
            return None;
        }

        let ip_header_length = usize::from(packet[0] & 0x0F) * 4;
        if packet.len() < ip_header_length + 20 {
            return None;
        }
        if packet[9] != 6 {
            return None;
        }

        let tcp_offset = ip_header_length;
        let tcp_header_length = usize::from(packet[tcp_offset + 12] >> 4) * 4;
        if packet.len() < tcp_offset + tcp_header_length {
            return None;
        }

        Some(TestTcpSegment {
            seq: u32::from_be_bytes(packet[tcp_offset + 4..tcp_offset + 8].try_into().ok()?),
            ack: u32::from_be_bytes(packet[tcp_offset + 8..tcp_offset + 12].try_into().ok()?),
            flags: packet[tcp_offset + 13],
            payload: packet[tcp_offset + tcp_header_length..].to_vec(),
        })
    }

    fn internet_checksum(bytes: &[u8]) -> u16 {
        let mut sum = 0u32;
        for chunk in bytes.chunks(2) {
            let word = match chunk {
                [high, low] => u16::from_be_bytes([*high, *low]) as u32,
                [high] => u16::from_be_bytes([*high, 0]) as u32,
                _ => 0,
            };
            sum = sum.wrapping_add(word);
        }

        while (sum >> 16) != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16);
        }

        !(sum as u16)
    }

    fn tcp_checksum(source_ip: Ipv4Addr, destination_ip: Ipv4Addr, tcp_segment: &[u8]) -> u16 {
        let mut pseudo_header = Vec::with_capacity(12 + tcp_segment.len());
        pseudo_header.extend_from_slice(&source_ip.octets());
        pseudo_header.extend_from_slice(&destination_ip.octets());
        pseudo_header.push(0);
        pseudo_header.push(6);
        pseudo_header.extend_from_slice(
            &u16::try_from(tcp_segment.len())
                .expect("tcp length")
                .to_be_bytes(),
        );
        pseudo_header.extend_from_slice(tcp_segment);
        internet_checksum(&pseudo_header)
    }

    struct TestTcpSegment {
        seq: u32,
        ack: u32,
        flags: u8,
        payload: Vec<u8>,
    }

    const TCP_ACK: u8 = 0x10;
    const TCP_PSH: u8 = 0x08;
    const TCP_SYN: u8 = 0x02;
}
