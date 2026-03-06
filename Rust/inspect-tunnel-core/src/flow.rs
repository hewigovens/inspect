use crate::model::{PacketObservation, TransportProtocol};
use crate::packet::{
    ParsedPacket, extract_tls_client_hello_server_name, extract_tls_server_certificates,
    observation_from_parsed_packet,
};
use std::collections::HashMap;

#[derive(Default)]
pub struct FlowTracker {
    tcp_flows: HashMap<TcpFlowKey, TcpFlowState>,
}

impl FlowTracker {
    pub fn clear(&mut self) {
        self.tcp_flows.clear();
    }

    pub fn observe(&mut self, parsed: &ParsedPacket) -> PacketObservation {
        let mut observation = observation_from_parsed_packet(parsed);

        if parsed.transport != TransportProtocol::Tcp {
            return observation;
        }

        let Some(local_port) = parsed.local_port else {
            return observation;
        };
        let Some(remote_port) = parsed.remote_port else {
            return observation;
        };
        let Some(payload) = parsed.tcp_payload.as_deref() else {
            return observation;
        };

        let key = TcpFlowKey {
            client_host: parsed.local_host.clone(),
            client_port: local_port,
            server_host: parsed.remote_host.clone(),
            server_port: remote_port,
        };
        let state = self.tcp_flows.entry(key).or_default();

        if state.server_name.is_none() {
            if let Some(server_name) = extract_tls_client_hello_server_name(payload)
                .or_else(|| state.client_hello_capture.ingest(payload))
            {
                state.server_name = Some(server_name);
            }
        } else {
            let _ = state.client_hello_capture.ingest(payload);
        }

        if state.captured_certificate_chain_der_hex.is_none() {
            if let Some(certificates) = extract_tls_server_certificates(payload)
                .or_else(|| state.server_certificate_capture.ingest(payload))
            {
                state.captured_certificate_chain_der_hex =
                    Some(certificates.into_iter().map(hex::encode).collect());
            }
        } else {
            let _ = state.server_certificate_capture.ingest(payload);
        }

        if observation.server_name.is_none() {
            observation.server_name = state.server_name.clone();
        }
        if observation.captured_certificate_chain_der_hex.is_none() {
            observation.captured_certificate_chain_der_hex =
                state.captured_certificate_chain_der_hex.clone();
        }

        observation
    }
}

#[derive(Clone, Debug, Hash, PartialEq, Eq)]
struct TcpFlowKey {
    client_host: String,
    client_port: u16,
    server_host: String,
    server_port: u16,
}

#[derive(Default)]
struct TcpFlowState {
    client_hello_capture: TlsClientHelloCapture,
    server_certificate_capture: TlsServerCertificateCapture,
    server_name: Option<String>,
    captured_certificate_chain_der_hex: Option<Vec<String>>,
}

#[derive(Default)]
struct TlsClientHelloCapture {
    buffer: Vec<u8>,
}

impl TlsClientHelloCapture {
    fn ingest(&mut self, data: &[u8]) -> Option<String> {
        if data.is_empty() {
            return None;
        }

        const MAXIMUM_BUFFERED_BYTES: usize = 32 * 1024;
        if self.buffer.len() < MAXIMUM_BUFFERED_BYTES {
            let remaining_capacity = MAXIMUM_BUFFERED_BYTES - self.buffer.len();
            self.buffer
                .extend_from_slice(&data[..data.len().min(remaining_capacity)]);
        }

        extract_tls_client_hello_server_name(&self.buffer)
    }
}

#[derive(Default)]
struct TlsServerCertificateCapture {
    buffer: Vec<u8>,
    did_complete_capture: bool,
}

impl TlsServerCertificateCapture {
    fn ingest(&mut self, data: &[u8]) -> Option<Vec<Vec<u8>>> {
        if self.did_complete_capture || data.is_empty() {
            return None;
        }

        const MAXIMUM_BUFFERED_BYTES: usize = 128 * 1024;
        if self.buffer.len() >= MAXIMUM_BUFFERED_BYTES {
            self.did_complete_capture = true;
            return None;
        }

        let remaining_capacity = MAXIMUM_BUFFERED_BYTES - self.buffer.len();
        self.buffer
            .extend_from_slice(&data[..data.len().min(remaining_capacity)]);

        let certificates = extract_tls_server_certificates(&self.buffer);
        if certificates.is_some() {
            self.did_complete_capture = true;
        }
        certificates
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::PacketDirection;
    use crate::packet::{
        build_tls_client_hello_packet, build_tls_server_certificate_packet, parse_packet,
    };

    #[test]
    fn reassembles_fragmented_client_hello() {
        let packet = build_tls_client_hello_packet("10.0.0.2", "93.184.216.34", 443, "example.com")
            .expect("build packet");
        let split_at = packet.len() - 10;
        let first = patch_packet_payload(&packet, &packet[payload_offset(&packet)..split_at]);
        let second = patch_packet_payload(&packet, &packet[split_at..]);

        let mut tracker = FlowTracker::default();
        let first_observation = tracker
            .observe(&parse_packet(&first, PacketDirection::Outbound).expect("first parsed"));
        assert!(first_observation.server_name.is_none());

        let second_observation = tracker
            .observe(&parse_packet(&second, PacketDirection::Outbound).expect("second parsed"));
        assert_eq!(
            second_observation.server_name.as_deref(),
            Some("example.com")
        );
    }

    #[test]
    fn reassembles_fragmented_server_certificate() {
        let certificate = vec![0x30, 0x03, 0x02, 0x01, 0x05];
        let packet = build_tls_server_certificate_packet(
            "93.184.216.34",
            "10.0.0.2",
            443,
            &[certificate.clone()],
        )
        .expect("build packet");
        let payload_offset = payload_offset(&packet);
        let split_at = payload_offset + 12;
        let first = patch_packet_payload(&packet, &packet[payload_offset..split_at]);
        let second = patch_packet_payload(&packet, &packet[split_at..]);

        let mut tracker = FlowTracker::default();
        let first_observation =
            tracker.observe(&parse_packet(&first, PacketDirection::Inbound).expect("first parsed"));
        assert!(
            first_observation
                .captured_certificate_chain_der_hex
                .is_none()
        );

        let second_observation = tracker
            .observe(&parse_packet(&second, PacketDirection::Inbound).expect("second parsed"));
        assert_eq!(
            second_observation.captured_certificate_chain_der_hex,
            Some(vec![hex::encode(certificate)])
        );
    }

    fn payload_offset(packet: &[u8]) -> usize {
        let ip_header_length = usize::from(packet[0] & 0x0F) * 4;
        let tcp_header_length = usize::from((packet[ip_header_length + 12] >> 4) & 0x0F) * 4;
        ip_header_length + tcp_header_length
    }

    fn patch_packet_payload(packet: &[u8], payload: &[u8]) -> Vec<u8> {
        let payload_offset = payload_offset(packet);
        let mut patched = packet[..payload_offset].to_vec();
        patched.extend_from_slice(payload);
        let total_length = u16::try_from(patched.len()).expect("length fits");
        patched[2] = (total_length >> 8) as u8;
        patched[3] = total_length as u8;
        patched
    }
}
