use std::fs;
use std::path::Path;

pub fn read_pcap_ip_packets(path: &Path) -> Result<Vec<Vec<u8>>, String> {
    let bytes = fs::read(path)
        .map_err(|error| format!("failed to read pcap file {}: {error}", path.display()))?;
    if bytes.len() < 24 {
        return Err("pcap file is too short".to_string());
    }

    let (byte_order, link_type, mut offset) = parse_global_header(&bytes)?;
    let mut packets = Vec::new();

    while offset + 16 <= bytes.len() {
        let included_length = read_u32(&bytes, offset + 8, byte_order)? as usize;
        offset += 16;

        if offset + included_length > bytes.len() {
            return Err("pcap packet length exceeds file bounds".to_string());
        }

        let raw_packet = &bytes[offset..offset + included_length];
        offset += included_length;

        if let Some(ip_packet) = strip_link_layer(raw_packet, link_type)? {
            packets.push(ip_packet);
        }
    }

    Ok(packets)
}

#[derive(Clone, Copy)]
enum ByteOrder {
    Little,
    Big,
}

fn parse_global_header(bytes: &[u8]) -> Result<(ByteOrder, u32, usize), String> {
    let magic = &bytes[..4];
    let byte_order = match magic {
        [0xd4, 0xc3, 0xb2, 0xa1] | [0x4d, 0x3c, 0xb2, 0xa1] => ByteOrder::Little,
        [0xa1, 0xb2, 0xc3, 0xd4] | [0xa1, 0xb2, 0x3c, 0x4d] => ByteOrder::Big,
        _ => return Err("unsupported pcap magic number".to_string()),
    };

    let link_type = read_u32(bytes, 20, byte_order)?;
    Ok((byte_order, link_type, 24))
}

fn strip_link_layer(packet: &[u8], link_type: u32) -> Result<Option<Vec<u8>>, String> {
    match link_type {
        0 | 108 => strip_loopback(packet),
        1 => strip_ethernet(packet),
        101 => strip_raw(packet),
        _ => Err(format!("unsupported pcap link type {link_type}")),
    }
}

fn strip_loopback(packet: &[u8]) -> Result<Option<Vec<u8>>, String> {
    if packet.len() < 4 {
        return Ok(None);
    }

    let family_le = u32::from_le_bytes([packet[0], packet[1], packet[2], packet[3]]);
    let family_be = u32::from_be_bytes([packet[0], packet[1], packet[2], packet[3]]);
    let payload = &packet[4..];

    if matches!(family_le, 2) || matches!(family_be, 2) {
        return Ok((payload.first().is_some_and(|byte| byte >> 4 == 4)).then(|| payload.to_vec()));
    }

    if matches!(family_le, 24 | 28 | 30) || matches!(family_be, 24 | 28 | 30) {
        return Ok((payload.first().is_some_and(|byte| byte >> 4 == 6)).then(|| payload.to_vec()));
    }

    Ok(match payload.first().map(|byte| byte >> 4) {
        Some(4 | 6) => Some(payload.to_vec()),
        _ => None,
    })
}

fn strip_ethernet(packet: &[u8]) -> Result<Option<Vec<u8>>, String> {
    if packet.len() < 14 {
        return Ok(None);
    }

    let mut offset = 14usize;
    let mut ethertype = u16::from_be_bytes([packet[12], packet[13]]);
    if matches!(ethertype, 0x8100 | 0x88a8) {
        if packet.len() < 18 {
            return Ok(None);
        }
        ethertype = u16::from_be_bytes([packet[16], packet[17]]);
        offset = 18;
    }

    match ethertype {
        0x0800 | 0x86dd => Ok(Some(packet[offset..].to_vec())),
        _ => Ok(None),
    }
}

fn strip_raw(packet: &[u8]) -> Result<Option<Vec<u8>>, String> {
    Ok(match packet.first().map(|byte| byte >> 4) {
        Some(4 | 6) => Some(packet.to_vec()),
        _ => None,
    })
}

fn read_u32(bytes: &[u8], offset: usize, byte_order: ByteOrder) -> Result<u32, String> {
    let slice = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| "pcap header is truncated".to_string())?;
    let value = match byte_order {
        ByteOrder::Little => u32::from_le_bytes([slice[0], slice[1], slice[2], slice[3]]),
        ByteOrder::Big => u32::from_be_bytes([slice[0], slice[1], slice[2], slice[3]]),
    };
    Ok(value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn reads_raw_ipv4_packet_from_pcap() {
        let packet = vec![
            0x45, 0x00, 0x00, 0x14, 0, 0, 0, 0, 64, 6, 0, 0, 10, 0, 0, 2, 1, 1, 1, 1,
        ];
        let pcap = build_pcap(101, &[packet.clone()]);
        let mut file = NamedTempFile::new().expect("tempfile");
        file.write_all(&pcap).expect("write pcap");

        let packets = read_pcap_ip_packets(file.path()).expect("read pcap");
        assert_eq!(packets, vec![packet]);
    }

    #[test]
    fn reads_ethernet_ipv4_packet_from_pcap() {
        let ip_packet = vec![
            0x45, 0x00, 0x00, 0x14, 0, 0, 0, 0, 64, 6, 0, 0, 10, 0, 0, 2, 1, 1, 1, 1,
        ];
        let mut ethernet = vec![0; 12];
        ethernet.extend_from_slice(&0x0800u16.to_be_bytes());
        ethernet.extend_from_slice(&ip_packet);

        let pcap = build_pcap(1, &[ethernet]);
        let mut file = NamedTempFile::new().expect("tempfile");
        file.write_all(&pcap).expect("write pcap");

        let packets = read_pcap_ip_packets(file.path()).expect("read pcap");
        assert_eq!(packets, vec![ip_packet]);
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
