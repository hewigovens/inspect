use crate::model::{PacketDirection, PacketObservation, ReplayPacket, TransportProtocol};
use crate::pcap::read_pcap_ip_packets;
use std::fs;
use std::path::{Path, PathBuf};
use std::{
    collections::HashSet,
    net::{Ipv4Addr, Ipv6Addr},
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ParsedPacket {
    pub direction: PacketDirection,
    pub transport: TransportProtocol,
    pub source_host: String,
    pub destination_host: String,
    pub source_port: Option<u16>,
    pub destination_port: Option<u16>,
    pub local_host: String,
    pub remote_host: String,
    pub local_port: Option<u16>,
    pub remote_port: Option<u16>,
    pub tcp_payload: Option<Vec<u8>>,
    pub packet_bytes: usize,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MaterializedReplayPacket {
    pub direction: PacketDirection,
    pub bytes: Vec<u8>,
}

pub fn parse_packet(packet: &[u8], direction: PacketDirection) -> Option<ParsedPacket> {
    let first_byte = *packet.first()?;
    let ip_version = first_byte >> 4;

    match ip_version {
        4 => parse_ipv4_packet(packet, direction),
        6 => parse_ipv6_packet(packet, direction),
        _ => None,
    }
}

pub fn strip_utun_header(packet: &[u8]) -> &[u8] {
    if packet.is_empty() {
        return packet;
    }

    let version = packet[0] >> 4;
    if version == 4 || version == 6 {
        return packet;
    }

    if packet.len() <= 4 {
        return packet;
    }

    let family_ne = u32::from_ne_bytes([packet[0], packet[1], packet[2], packet[3]]);
    let family_be = u32::from_be_bytes([packet[0], packet[1], packet[2], packet[3]]);
    let body = &packet[4..];
    let body_version = body.first().map(|value| value >> 4);
    let matches_family = matches!(family_ne, value if value == libc::AF_INET as u32 || value == libc::AF_INET6 as u32)
        || matches!(family_be, value if value == libc::AF_INET as u32 || value == libc::AF_INET6 as u32);

    if matches_family && matches!(body_version, Some(4) | Some(6)) {
        body
    } else {
        packet
    }
}

pub fn infer_packet_direction(
    packet: &[u8],
    local_hosts: &HashSet<String>,
) -> Option<PacketDirection> {
    let packet = strip_utun_header(packet);
    let (source_host, destination_host) = packet_hosts(packet)?;
    let source_is_local = local_hosts.contains(&source_host);
    let destination_is_local = local_hosts.contains(&destination_host);

    match (source_is_local, destination_is_local) {
        (true, false) => Some(PacketDirection::Outbound),
        (false, true) => Some(PacketDirection::Inbound),
        (true, true) => Some(PacketDirection::Outbound),
        (false, false) => None,
    }
}

pub fn summarize_packet(packet: &[u8], direction: PacketDirection) -> Option<PacketObservation> {
    let parsed = parse_packet(packet, direction)?;
    Some(observation_from_parsed_packet(&parsed))
}

pub fn observation_from_parsed_packet(parsed: &ParsedPacket) -> PacketObservation {
    let server_name = parsed
        .tcp_payload
        .as_deref()
        .and_then(extract_tls_client_hello_server_name);
    let captured_certificate_chain_der_hex = parsed
        .tcp_payload
        .as_deref()
        .and_then(extract_tls_server_certificates)
        .map(|certificates| certificates.into_iter().map(hex::encode).collect());

    PacketObservation {
        direction: parsed.direction,
        transport: parsed.transport,
        remote_host: parsed.remote_host.clone(),
        remote_port: parsed.remote_port,
        server_name,
        captured_certificate_chain_der_hex,
        packet_bytes: parsed.packet_bytes,
    }
}

pub fn materialize_replay_packets(
    packet: &ReplayPacket,
    base_dir: Option<&Path>,
) -> Result<Vec<MaterializedReplayPacket>, String> {
    match packet {
        ReplayPacket::Raw { direction, hex, .. } => Ok(vec![MaterializedReplayPacket {
            direction: *direction,
            bytes: decode_hex(hex)?,
        }]),
        ReplayPacket::RawFile {
            direction, path, ..
        } => {
            let payload_path = resolve_path(base_dir, path);
            let hex_payload = fs::read_to_string(&payload_path).map_err(|error| {
                format!(
                    "failed to read raw packet file {}: {error}",
                    payload_path.display()
                )
            })?;
            Ok(vec![MaterializedReplayPacket {
                direction: *direction,
                bytes: decode_hex(&hex_payload)?,
            }])
        }
        ReplayPacket::PcapFile {
            direction, path, ..
        } => {
            let pcap_path = resolve_path(base_dir, path);
            let packets = read_pcap_ip_packets(&pcap_path)?;
            Ok(packets
                .into_iter()
                .map(|bytes| MaterializedReplayPacket {
                    direction: *direction,
                    bytes,
                })
                .collect())
        }
        ReplayPacket::TlsClientHello {
            direction,
            server_name,
            remote_host,
            remote_port,
            source_host,
            ..
        } => Ok(vec![MaterializedReplayPacket {
            direction: *direction,
            bytes: build_tls_client_hello_packet(
                source_host.as_deref().unwrap_or("10.0.0.2"),
                remote_host,
                *remote_port,
                server_name,
            )?,
        }]),
        ReplayPacket::TlsClientHelloFragments {
            direction,
            server_name,
            remote_host,
            remote_port,
            source_host,
            fragment_sizes,
            ..
        } => {
            let packet = build_tls_client_hello_packet(
                source_host.as_deref().unwrap_or("10.0.0.2"),
                remote_host,
                *remote_port,
                server_name,
            )?;
            let fragments = split_tcp_packet_payload(&packet, fragment_sizes)?;
            Ok(fragments
                .into_iter()
                .map(|bytes| MaterializedReplayPacket {
                    direction: *direction,
                    bytes,
                })
                .collect())
        }
        ReplayPacket::TlsServerCertificate {
            direction,
            remote_host,
            remote_port,
            certificate_files,
            source_host,
            ..
        } => {
            let certificates = load_certificate_files(certificate_files, base_dir)?;
            Ok(vec![MaterializedReplayPacket {
                direction: *direction,
                bytes: build_tls_server_certificate_packet(
                    remote_host,
                    source_host.as_deref().unwrap_or("10.0.0.2"),
                    *remote_port,
                    &certificates,
                )?,
            }])
        }
        ReplayPacket::TlsServerCertificateFragments {
            direction,
            remote_host,
            remote_port,
            certificate_files,
            source_host,
            fragment_sizes,
            ..
        } => {
            let certificates = load_certificate_files(certificate_files, base_dir)?;
            let packet = build_tls_server_certificate_packet(
                remote_host,
                source_host.as_deref().unwrap_or("10.0.0.2"),
                *remote_port,
                &certificates,
            )?;
            let fragments = split_tcp_packet_payload(&packet, fragment_sizes)?;
            Ok(fragments
                .into_iter()
                .map(|bytes| MaterializedReplayPacket {
                    direction: *direction,
                    bytes,
                })
                .collect())
        }
    }
}

pub fn extract_tls_client_hello_server_name(payload: &[u8]) -> Option<String> {
    if payload.len() < 5 {
        return None;
    }

    if payload[0] != 0x16 || payload[1] != 0x03 {
        return None;
    }

    let record_length = usize::from(read_u16(payload, 3)?);
    let record_end = payload.len().min(5 + record_length);
    if record_end <= 9 {
        return None;
    }

    let mut cursor = 5usize;
    if payload[cursor] != 0x01 {
        return None;
    }
    if cursor + 4 > record_end {
        return None;
    }

    let handshake_length = read_u24(payload, cursor + 1)?;
    cursor += 4;
    let handshake_end = record_end.min(cursor + handshake_length);
    if handshake_end <= cursor {
        return None;
    }

    if cursor + 34 > handshake_end {
        return None;
    }
    cursor += 34;

    let session_id_length = usize::from(*payload.get(cursor)?);
    cursor += 1 + session_id_length;
    if cursor > handshake_end {
        return None;
    }

    let cipher_suites_length = usize::from(read_u16(payload, cursor)?);
    cursor += 2 + cipher_suites_length;
    if cursor > handshake_end {
        return None;
    }

    let compression_methods_length = usize::from(*payload.get(cursor)?);
    cursor += 1 + compression_methods_length;
    if cursor > handshake_end {
        return None;
    }

    let extensions_length = usize::from(read_u16(payload, cursor)?);
    cursor += 2;
    let extensions_end = handshake_end.min(cursor + extensions_length);
    if extensions_end <= cursor {
        return None;
    }

    while cursor + 4 <= extensions_end {
        let extension_type = read_u16(payload, cursor)?;
        let extension_length = usize::from(read_u16(payload, cursor + 2)?);
        cursor += 4;

        if cursor + extension_length > extensions_end {
            return None;
        }

        if extension_type == 0 {
            return parse_server_name_extension(payload, cursor, extension_length);
        }

        cursor += extension_length;
    }

    None
}

pub fn extract_tls_server_certificates(payload: &[u8]) -> Option<Vec<Vec<u8>>> {
    let mut record_buffer = payload.to_vec();
    let mut handshake_buffer = Vec::new();

    while record_buffer.len() >= 5 {
        let content_type = record_buffer[0];
        let major_version = record_buffer[1];
        let record_length = usize::from(read_u16(&record_buffer, 3)?);

        if major_version != 0x03 {
            return None;
        }

        let total_record_length = 5 + record_length;
        if record_buffer.len() < total_record_length {
            return None;
        }

        let body = record_buffer[5..total_record_length].to_vec();
        record_buffer.drain(..total_record_length);

        match content_type {
            0x16 => {
                handshake_buffer.extend_from_slice(&body);
                if let Some(certificates) = parse_handshake_messages(&mut handshake_buffer) {
                    return Some(certificates);
                }
            }
            0x14 => continue,
            0x15 | 0x17 => return None,
            _ => return None,
        }
    }

    None
}

pub fn build_tls_client_hello_packet(
    source_host: &str,
    remote_host: &str,
    remote_port: u16,
    server_name: &str,
) -> Result<Vec<u8>, String> {
    let tls_payload = build_tls_client_hello_record(server_name)?;
    build_ipv4_tcp_packet(source_host, remote_host, 49_512, remote_port, &tls_payload)
}

pub fn build_tls_server_certificate_packet(
    remote_host: &str,
    source_host: &str,
    remote_port: u16,
    certificates: &[Vec<u8>],
) -> Result<Vec<u8>, String> {
    let tls_payload = build_tls13_certificate_record(certificates)?;
    build_ipv4_tcp_packet(remote_host, source_host, remote_port, 49_512, &tls_payload)
}

fn parse_ipv4_packet(packet: &[u8], direction: PacketDirection) -> Option<ParsedPacket> {
    if packet.len() < 20 {
        return None;
    }

    let header_length = usize::from(first_nibble(packet[0])) * 4;
    if packet.len() < header_length {
        return None;
    }

    let protocol_number = packet[9];
    let source_host = ipv4_string(&packet[12..16]);
    let destination_host = ipv4_string(&packet[16..20]);
    build_parsed_packet(
        packet,
        direction,
        protocol_number,
        header_length,
        source_host,
        destination_host,
    )
}

fn parse_ipv6_packet(packet: &[u8], direction: PacketDirection) -> Option<ParsedPacket> {
    if packet.len() < 40 {
        return None;
    }

    let protocol_number = packet[6];
    let source_host = ipv6_string(&packet[8..24]);
    let destination_host = ipv6_string(&packet[24..40]);
    build_parsed_packet(
        packet,
        direction,
        protocol_number,
        40,
        source_host,
        destination_host,
    )
}

fn packet_hosts(packet: &[u8]) -> Option<(String, String)> {
    let first_byte = *packet.first()?;
    let ip_version = first_byte >> 4;
    let parsed = match ip_version {
        4 => parse_ipv4_packet(packet, PacketDirection::Outbound)?,
        6 => parse_ipv6_packet(packet, PacketDirection::Outbound)?,
        _ => return None,
    };

    Some((parsed.source_host, parsed.destination_host))
}

fn build_parsed_packet(
    packet: &[u8],
    direction: PacketDirection,
    protocol_number: u8,
    transport_offset: usize,
    source_host: String,
    destination_host: String,
) -> Option<ParsedPacket> {
    let transport = transport_for(protocol_number);
    let (source_port, destination_port) =
        transport_ports(packet, protocol_number, transport_offset);
    let tcp_payload = tcp_payload(packet, protocol_number, transport_offset).map(ToOwned::to_owned);

    let (local_host, remote_host, local_port, remote_port) = match direction {
        PacketDirection::Outbound => (
            source_host.clone(),
            destination_host.clone(),
            source_port,
            destination_port,
        ),
        PacketDirection::Inbound => (
            destination_host.clone(),
            source_host.clone(),
            destination_port,
            source_port,
        ),
    };

    Some(ParsedPacket {
        direction,
        transport,
        source_host,
        destination_host,
        source_port,
        destination_port,
        local_host,
        remote_host,
        local_port,
        remote_port,
        tcp_payload,
        packet_bytes: packet.len(),
    })
}

fn transport_for(protocol_number: u8) -> TransportProtocol {
    match protocol_number {
        6 => TransportProtocol::Tcp,
        17 => TransportProtocol::Udp,
        _ => TransportProtocol::Unknown,
    }
}

fn transport_ports(
    packet: &[u8],
    protocol_number: u8,
    transport_offset: usize,
) -> (Option<u16>, Option<u16>) {
    if protocol_number != 6 && protocol_number != 17 {
        return (None, None);
    }
    if packet.len() < transport_offset + 4 {
        return (None, None);
    }

    (
        read_u16(packet, transport_offset),
        read_u16(packet, transport_offset + 2),
    )
}

fn tcp_payload(packet: &[u8], protocol_number: u8, transport_offset: usize) -> Option<&[u8]> {
    if protocol_number != 6 || packet.len() < transport_offset + 20 {
        return None;
    }

    let tcp_header_length = usize::from((packet[transport_offset + 12] >> 4) & 0x0F) * 4;
    if tcp_header_length < 20 {
        return None;
    }

    let payload_offset = transport_offset + tcp_header_length;
    (payload_offset < packet.len()).then_some(&packet[payload_offset..])
}

fn parse_handshake_messages(buffer: &mut Vec<u8>) -> Option<Vec<Vec<u8>>> {
    while buffer.len() >= 4 {
        let handshake_type = buffer[0];
        let handshake_length = read_u24(buffer, 1)?;
        let total_handshake_length = 4 + handshake_length;
        if buffer.len() < total_handshake_length {
            return None;
        }

        let body = buffer[4..total_handshake_length].to_vec();
        buffer.drain(..total_handshake_length);

        if handshake_type != 0x0B {
            continue;
        }

        return parse_tls13_certificate_message(&body)
            .or_else(|| parse_tls12_certificate_message(&body));
    }

    None
}

fn parse_tls12_certificate_message(body: &[u8]) -> Option<Vec<Vec<u8>>> {
    if body.len() < 3 {
        return None;
    }

    let total_certificates_length = read_u24(body, 0)?;
    if body.len() != 3 + total_certificates_length {
        return None;
    }

    let mut cursor = 3usize;
    let mut certificates = Vec::new();

    while cursor < body.len() {
        let certificate_length = read_u24(body, cursor)?;
        cursor += 3;
        if cursor + certificate_length > body.len() {
            return None;
        }

        certificates.push(body[cursor..cursor + certificate_length].to_vec());
        cursor += certificate_length;
    }

    (!certificates.is_empty()).then_some(certificates)
}

fn parse_tls13_certificate_message(body: &[u8]) -> Option<Vec<Vec<u8>>> {
    if body.len() < 4 {
        return None;
    }

    let request_context_length = usize::from(body[0]);
    let certificate_list_offset = 1 + request_context_length;
    if certificate_list_offset + 3 > body.len() {
        return None;
    }

    let total_certificates_length = read_u24(body, certificate_list_offset)?;
    let certificates_start = certificate_list_offset + 3;
    if certificates_start + total_certificates_length != body.len() {
        return None;
    }

    let mut cursor = certificates_start;
    let mut certificates = Vec::new();

    while cursor < body.len() {
        let certificate_length = read_u24(body, cursor)?;
        cursor += 3;
        if cursor + certificate_length > body.len() {
            return None;
        }

        certificates.push(body[cursor..cursor + certificate_length].to_vec());
        cursor += certificate_length;

        let extensions_length = usize::from(read_u16(body, cursor)?);
        cursor += 2;
        if cursor + extensions_length > body.len() {
            return None;
        }
        cursor += extensions_length;
    }

    (!certificates.is_empty()).then_some(certificates)
}

fn parse_server_name_extension(bytes: &[u8], offset: usize, length: usize) -> Option<String> {
    if length < 2 {
        return None;
    }

    let end = offset + length;
    let mut cursor = offset;
    let list_length = usize::from(read_u16(bytes, cursor)?);
    cursor += 2;
    let list_end = end.min(cursor + list_length);
    if list_end <= cursor {
        return None;
    }

    while cursor + 3 <= list_end {
        let name_type = *bytes.get(cursor)?;
        let name_length = usize::from(read_u16(bytes, cursor + 1)?);
        cursor += 3;

        if cursor + name_length > list_end {
            return None;
        }

        if name_type == 0 {
            let name = std::str::from_utf8(&bytes[cursor..cursor + name_length])
                .ok()?
                .trim();
            if name.is_empty() {
                return None;
            }
            return Some(name.to_lowercase());
        }

        cursor += name_length;
    }

    None
}

fn load_certificate_files(
    certificate_files: &[String],
    base_dir: Option<&Path>,
) -> Result<Vec<Vec<u8>>, String> {
    let mut certificates = Vec::with_capacity(certificate_files.len());
    for file in certificate_files {
        let path = resolve_path(base_dir, file);
        let bytes = fs::read(&path).map_err(|error| {
            format!(
                "failed to read certificate file {}: {error}",
                path.display()
            )
        })?;
        certificates.push(bytes);
    }
    Ok(certificates)
}

fn split_tcp_packet_payload(
    packet: &[u8],
    fragment_sizes: &[usize],
) -> Result<Vec<Vec<u8>>, String> {
    if fragment_sizes.is_empty() {
        return Ok(vec![packet.to_vec()]);
    }

    let first_byte = *packet
        .first()
        .ok_or_else(|| "packet must not be empty".to_string())?;
    let ip_version = first_byte >> 4;
    let (ip_header_length, transport_offset) = match ip_version {
        4 => {
            let header_length = usize::from(first_nibble(first_byte)) * 4;
            (header_length, header_length)
        }
        6 => (40, 40),
        _ => return Err("only IPv4/IPv6 TCP packets are supported for fragmentation".to_string()),
    };

    if packet.len() < transport_offset + 20 {
        return Err("packet is too short to contain a TCP header".to_string());
    }

    let tcp_header_length = usize::from((packet[transport_offset + 12] >> 4) & 0x0F) * 4;
    if tcp_header_length < 20 {
        return Err("invalid TCP header length".to_string());
    }

    let payload_offset = transport_offset + tcp_header_length;
    if payload_offset > packet.len() {
        return Err("invalid payload offset".to_string());
    }

    let header = &packet[..payload_offset];
    let payload = &packet[payload_offset..];
    if payload.is_empty() {
        return Err("packet has no TCP payload to fragment".to_string());
    }

    let mut fragments = Vec::new();
    let mut cursor = 0usize;
    for &size in fragment_sizes {
        if size == 0 {
            return Err("fragment_sizes must not contain zero".to_string());
        }
        if cursor + size > payload.len() {
            return Err("fragment_sizes exceed available TCP payload".to_string());
        }

        fragments.push(assemble_fragment(
            ip_version,
            ip_header_length,
            header,
            &payload[cursor..cursor + size],
        )?);
        cursor += size;
    }

    if cursor < payload.len() {
        fragments.push(assemble_fragment(
            ip_version,
            ip_header_length,
            header,
            &payload[cursor..],
        )?);
    }

    Ok(fragments)
}

fn assemble_fragment(
    ip_version: u8,
    ip_header_length: usize,
    header: &[u8],
    payload: &[u8],
) -> Result<Vec<u8>, String> {
    let mut packet = header.to_vec();
    packet.extend_from_slice(payload);

    match ip_version {
        4 => {
            let total_length = u16::try_from(packet.len())
                .map_err(|_| "fragmented IPv4 packet too large".to_string())?;
            packet[2] = (total_length >> 8) as u8;
            packet[3] = total_length as u8;
        }
        6 => {
            let payload_length = u16::try_from(packet.len() - ip_header_length)
                .map_err(|_| "fragmented IPv6 payload too large".to_string())?;
            packet[4] = (payload_length >> 8) as u8;
            packet[5] = payload_length as u8;
        }
        _ => return Err("unsupported IP version".to_string()),
    }

    Ok(packet)
}

fn build_ipv4_tcp_packet(
    source_host: &str,
    destination_host: &str,
    source_port: u16,
    destination_port: u16,
    payload: &[u8],
) -> Result<Vec<u8>, String> {
    let source_ip = parse_ipv4_address(source_host)?;
    let destination_ip = parse_ipv4_address(destination_host)?;
    let tcp_length = 20usize + payload.len();
    let total_length = 20usize + tcp_length;
    let total_length_u16 =
        u16::try_from(total_length).map_err(|_| "packet too large".to_string())?;

    let mut packet = Vec::with_capacity(total_length);
    packet.extend_from_slice(&[
        0x45,
        0x00,
        (total_length_u16 >> 8) as u8,
        total_length_u16 as u8,
        0x00,
        0x01,
        0x40,
        0x00,
        0x40,
        0x06,
        0x00,
        0x00,
    ]);
    packet.extend_from_slice(&source_ip);
    packet.extend_from_slice(&destination_ip);
    packet.extend_from_slice(&source_port.to_be_bytes());
    packet.extend_from_slice(&destination_port.to_be_bytes());
    packet.extend_from_slice(&0u32.to_be_bytes());
    packet.extend_from_slice(&0u32.to_be_bytes());
    packet.push(0x50);
    packet.push(0x18);
    packet.extend_from_slice(&0xFFFFu16.to_be_bytes());
    packet.extend_from_slice(&0u16.to_be_bytes());
    packet.extend_from_slice(&0u16.to_be_bytes());
    packet.extend_from_slice(payload);

    Ok(packet)
}

fn build_tls_client_hello_record(server_name: &str) -> Result<Vec<u8>, String> {
    let server_name_bytes = server_name.as_bytes();
    if server_name_bytes.is_empty() {
        return Err("server_name must not be empty".to_string());
    }
    let server_name_length =
        u16::try_from(server_name_bytes.len()).map_err(|_| "server_name too long".to_string())?;

    let server_name_list_length = u16::try_from(1usize + 2 + server_name_bytes.len())
        .map_err(|_| "server_name extension too large".to_string())?;
    let extension_length = u16::try_from(2usize + usize::from(server_name_list_length))
        .map_err(|_| "server_name extension length too large".to_string())?;

    let mut body = Vec::new();
    body.extend_from_slice(&[0x03, 0x03]);
    body.extend(std::iter::repeat_n(0x11, 32));
    body.push(0x00);
    body.extend_from_slice(&2u16.to_be_bytes());
    body.extend_from_slice(&[0x13, 0x01]);
    body.push(0x01);
    body.push(0x00);

    let extensions_length = 4usize + usize::from(extension_length);
    body.extend_from_slice(&(extensions_length as u16).to_be_bytes());
    body.extend_from_slice(&0u16.to_be_bytes());
    body.extend_from_slice(&extension_length.to_be_bytes());
    body.extend_from_slice(&server_name_list_length.to_be_bytes());
    body.push(0x00);
    body.extend_from_slice(&server_name_length.to_be_bytes());
    body.extend_from_slice(server_name_bytes);

    build_tls_record(0x01, &body, [0x03, 0x01])
}

fn build_tls13_certificate_record(certificates: &[Vec<u8>]) -> Result<Vec<u8>, String> {
    if certificates.is_empty() {
        return Err("certificate_files must not be empty".to_string());
    }

    let mut body = Vec::new();
    body.push(0x00);

    let mut certificate_list = Vec::new();
    for certificate in certificates {
        if certificate.len() > 0x00FF_FFFF {
            return Err("certificate too large".to_string());
        }
        push_u24(&mut certificate_list, certificate.len());
        certificate_list.extend_from_slice(certificate);
        certificate_list.extend_from_slice(&0u16.to_be_bytes());
    }

    if certificate_list.len() > 0x00FF_FFFF {
        return Err("certificate list too large".to_string());
    }

    push_u24(&mut body, certificate_list.len());
    body.extend_from_slice(&certificate_list);

    build_tls_record(0x0B, &body, [0x03, 0x03])
}

fn build_tls_record(handshake_type: u8, body: &[u8], version: [u8; 2]) -> Result<Vec<u8>, String> {
    if body.len() > 0x00FF_FFFF {
        return Err("handshake body too large".to_string());
    }

    let record_length = 4usize + body.len();
    let record_length_u16 =
        u16::try_from(record_length).map_err(|_| "TLS record too large".to_string())?;

    let mut record = Vec::with_capacity(5 + usize::from(record_length_u16));
    record.push(0x16);
    record.extend_from_slice(&version);
    record.extend_from_slice(&record_length_u16.to_be_bytes());
    record.push(handshake_type);
    push_u24(&mut record, body.len());
    record.extend_from_slice(body);
    Ok(record)
}

fn push_u24(bytes: &mut Vec<u8>, value: usize) {
    bytes.push(((value >> 16) & 0xFF) as u8);
    bytes.push(((value >> 8) & 0xFF) as u8);
    bytes.push((value & 0xFF) as u8);
}

fn decode_hex(input: &str) -> Result<Vec<u8>, String> {
    let normalized: String = input
        .chars()
        .filter(|ch| !ch.is_ascii_whitespace())
        .collect();
    hex::decode(normalized).map_err(|error| format!("invalid hex payload: {error}"))
}

fn parse_ipv4_address(address: &str) -> Result<[u8; 4], String> {
    let parsed: std::net::Ipv4Addr = address
        .parse()
        .map_err(|error| format!("invalid IPv4 address '{address}': {error}"))?;
    Ok(parsed.octets())
}

fn resolve_path(base_dir: Option<&Path>, path: &str) -> PathBuf {
    let candidate = PathBuf::from(path);
    if candidate.is_absolute() {
        candidate
    } else if let Some(base_dir) = base_dir {
        base_dir.join(candidate)
    } else {
        candidate
    }
}

fn ipv4_string(bytes: &[u8]) -> String {
    Ipv4Addr::new(bytes[0], bytes[1], bytes[2], bytes[3]).to_string()
}

fn ipv6_string(bytes: &[u8]) -> String {
    let address = Ipv6Addr::from(<[u8; 16]>::try_from(bytes).expect("ipv6 bytes"));
    address.to_string()
}

fn first_nibble(byte: u8) -> u8 {
    byte & 0x0F
}

fn read_u16(bytes: &[u8], offset: usize) -> Option<u16> {
    Some(u16::from_be_bytes([
        *bytes.get(offset)?,
        *bytes.get(offset + 1)?,
    ]))
}

fn read_u24(bytes: &[u8], offset: usize) -> Option<usize> {
    Some(
        (usize::from(*bytes.get(offset)?) << 16)
            | (usize::from(*bytes.get(offset + 1)?) << 8)
            | usize::from(*bytes.get(offset + 2)?),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::PacketDirection;
    use tempfile::tempdir;

    #[test]
    fn builds_and_extracts_sni_from_synthetic_packet() {
        let packet = build_tls_client_hello_packet("10.0.0.2", "93.184.216.34", 443, "example.com")
            .expect("build packet");

        let summary = summarize_packet(&packet, PacketDirection::Outbound).expect("summary");
        assert_eq!(summary.remote_host, "93.184.216.34");
        assert_eq!(summary.remote_port, Some(443));
        assert_eq!(summary.server_name.as_deref(), Some("example.com"));
        assert!(summary.captured_certificate_chain_der_hex.is_none());
    }

    #[test]
    fn extracts_inbound_remote_endpoint_from_source() {
        let packet = build_tls_client_hello_packet("140.82.112.4", "10.0.0.2", 443, "github.com")
            .expect("build packet");

        let summary = summarize_packet(&packet, PacketDirection::Inbound).expect("summary");
        assert_eq!(summary.remote_host, "140.82.112.4");
        assert_eq!(summary.remote_port, Some(49512));
        assert_eq!(summary.server_name.as_deref(), Some("github.com"));
    }

    #[test]
    fn extracts_certificate_chain_from_synthetic_packet() {
        let certificate = vec![0x30, 0x03, 0x02, 0x01, 0x05];
        let packet = build_tls_server_certificate_packet(
            "93.184.216.34",
            "10.0.0.2",
            443,
            &[certificate.clone()],
        )
        .expect("build packet");

        let summary = summarize_packet(&packet, PacketDirection::Inbound).expect("summary");
        assert_eq!(summary.remote_host, "93.184.216.34");
        assert_eq!(summary.remote_port, Some(443));
        assert_eq!(
            summary.captured_certificate_chain_der_hex,
            Some(vec![hex::encode(certificate)])
        );
    }

    #[test]
    fn loads_raw_packet_hex_from_file() {
        let temp_dir = tempdir().expect("tempdir");
        let packet_path = temp_dir.path().join("clienthello.hex");
        let packet = build_tls_client_hello_packet("10.0.0.2", "93.184.216.34", 443, "example.com")
            .expect("build packet");
        fs::write(&packet_path, hex::encode(packet)).expect("write packet hex");

        let materialized = materialize_replay_packets(
            &ReplayPacket::RawFile {
                direction: PacketDirection::Outbound,
                path: "clienthello.hex".to_string(),
                note: None,
            },
            Some(temp_dir.path()),
        )
        .expect("materialize");

        let summary =
            summarize_packet(&materialized[0].bytes, PacketDirection::Outbound).expect("summary");
        assert_eq!(summary.server_name.as_deref(), Some("example.com"));
    }

    #[test]
    fn splits_tcp_payload_into_fragments() {
        let packet = build_tls_client_hello_packet("10.0.0.2", "93.184.216.34", 443, "example.com")
            .expect("build packet");
        let fragments = split_tcp_packet_payload(&packet, &[20, 15]).expect("fragments");
        assert_eq!(fragments.len(), 3);
        assert!(fragments[0].len() < packet.len());
    }

    #[test]
    fn infers_packet_direction_from_local_hosts() {
        let packet =
            build_tls_client_hello_packet("198.18.0.1", "93.184.216.34", 443, "example.com")
                .expect("build packet");
        let local_hosts = HashSet::from([
            "198.18.0.1".to_string(),
            "fd00::1".to_string(),
            "198.18.0.2".to_string(),
        ]);

        assert_eq!(
            infer_packet_direction(&packet, &local_hosts),
            Some(PacketDirection::Outbound)
        );
    }

    #[test]
    fn strips_darwin_utun_header() {
        let packet =
            build_tls_client_hello_packet("198.18.0.1", "93.184.216.34", 443, "example.com")
                .expect("build packet");
        let mut framed = Vec::with_capacity(packet.len() + 4);
        framed.extend_from_slice(&(libc::AF_INET as u32).to_ne_bytes());
        framed.extend_from_slice(&packet);

        let stripped = strip_utun_header(&framed);
        assert_eq!(stripped, packet.as_slice());
    }
}
