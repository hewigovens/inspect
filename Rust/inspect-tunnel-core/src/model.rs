use serde::{Deserialize, Serialize};

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
pub struct InspectTunnelCoreStats {
    pub tx_packets: u64,
    pub tx_bytes: u64,
    pub rx_packets: u64,
    pub rx_bytes: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct InspectTunnelCoreConfig {
    pub ipv4_address: String,
    pub ipv6_address: String,
    pub dns_address: String,
    pub fake_ip_range: String,
    pub mtu: u16,
    pub monitor_enabled: bool,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum PacketDirection {
    Outbound,
    Inbound,
}

impl PacketDirection {
    pub fn label(self) -> &'static str {
        match self {
            Self::Outbound => "outbound",
            Self::Inbound => "inbound",
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum TransportProtocol {
    Tcp,
    Udp,
    Unknown,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct PacketObservation {
    pub direction: PacketDirection,
    pub transport: TransportProtocol,
    pub remote_host: String,
    pub remote_port: Option<u16>,
    pub server_name: Option<String>,
    pub captured_certificate_chain_der_hex: Option<Vec<String>>,
    pub packet_bytes: usize,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    tag = "kind"
)]
pub enum ReplayPacket {
    Raw {
        direction: PacketDirection,
        hex: String,
        note: Option<String>,
    },
    RawFile {
        direction: PacketDirection,
        path: String,
        note: Option<String>,
    },
    PcapFile {
        direction: PacketDirection,
        path: String,
        note: Option<String>,
    },
    TlsClientHello {
        direction: PacketDirection,
        server_name: String,
        remote_host: String,
        remote_port: u16,
        source_host: Option<String>,
        note: Option<String>,
    },
    TlsClientHelloFragments {
        direction: PacketDirection,
        server_name: String,
        remote_host: String,
        remote_port: u16,
        source_host: Option<String>,
        fragment_sizes: Vec<usize>,
        note: Option<String>,
    },
    TlsServerCertificate {
        direction: PacketDirection,
        remote_host: String,
        remote_port: u16,
        certificate_files: Vec<String>,
        source_host: Option<String>,
        note: Option<String>,
    },
    TlsServerCertificateFragments {
        direction: PacketDirection,
        remote_host: String,
        remote_port: u16,
        certificate_files: Vec<String>,
        source_host: Option<String>,
        fragment_sizes: Vec<usize>,
        note: Option<String>,
    },
}

impl ReplayPacket {
    pub fn direction(&self) -> PacketDirection {
        match self {
            Self::Raw { direction, .. }
            | Self::RawFile { direction, .. }
            | Self::PcapFile { direction, .. }
            | Self::TlsClientHello { direction, .. }
            | Self::TlsClientHelloFragments { direction, .. }
            | Self::TlsServerCertificate { direction, .. }
            | Self::TlsServerCertificateFragments { direction, .. } => *direction,
        }
    }

    pub fn note(&self) -> Option<&str> {
        match self {
            Self::Raw { note, .. }
            | Self::RawFile { note, .. }
            | Self::PcapFile { note, .. }
            | Self::TlsClientHello { note, .. }
            | Self::TlsClientHelloFragments { note, .. }
            | Self::TlsServerCertificate { note, .. }
            | Self::TlsServerCertificateFragments { note, .. } => note.as_deref(),
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReplayScenario {
    pub tun_fd: Option<i32>,
    pub log_file: Option<String>,
    pub config: InspectTunnelCoreConfig,
    pub packets: Vec<ReplayPacket>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReplayResult {
    pub version: String,
    pub packet_count: usize,
    pub observations: Vec<PacketObservation>,
    pub stats: InspectTunnelCoreStats,
    pub log_file: Option<String>,
}
