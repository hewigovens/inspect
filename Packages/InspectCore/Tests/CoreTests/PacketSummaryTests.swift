import Foundation
@testable import InspectCore
import Testing

// MARK: - IPv4 Packets

@Test
func parsesIPv4TCPPacket() {
    let packet = buildIPv4Packet(
        destinationIP: [93, 184, 216, 34],
        protocol: 6, // TCP
        destinationPort: 443
    )
    let summary = PacketSummary(packet: packet)
    #expect(summary != nil)
    #expect(summary?.remoteHost == "93.184.216.34")
    #expect(summary?.remotePort == 443)
    #expect(summary?.transport == .tcp)
}

@Test
func parsesIPv4UDPPacket() {
    let packet = buildIPv4Packet(
        destinationIP: [8, 8, 8, 8],
        protocol: 17, // UDP
        destinationPort: 443
    )
    let summary = PacketSummary(packet: packet)
    #expect(summary != nil)
    #expect(summary?.remoteHost == "8.8.8.8")
    #expect(summary?.remotePort == 443)
    #expect(summary?.transport == .udp)
}

@Test
func identifiesTLSPorts() {
    for port in [443, 8443, 9443] {
        let packet = buildIPv4Packet(
            destinationIP: [1, 1, 1, 1],
            protocol: 6,
            destinationPort: port
        )
        let summary = PacketSummary(packet: packet)
        #expect(summary?.isLikelyTLSPort == true, "Port \(port) should be TLS")
    }
}

@Test
func rejectsNonTLSPorts() {
    let packet = buildIPv4Packet(
        destinationIP: [1, 1, 1, 1],
        protocol: 6,
        destinationPort: 80
    )
    let summary = PacketSummary(packet: packet)
    #expect(summary?.isLikelyTLSPort == false)
}

@Test
func unknownTransportForNonTCPUDP() {
    let packet = buildIPv4Packet(
        destinationIP: [1, 1, 1, 1],
        protocol: 1, // ICMP
        destinationPort: nil
    )
    let summary = PacketSummary(packet: packet)
    #expect(summary != nil)
    #expect(summary?.transport == .unknown)
    #expect(summary?.remotePort == nil)
}

// MARK: - IPv6 Packets

@Test
func parsesIPv6TCPPacket() {
    let packet = buildIPv6Packet(
        destinationIP: [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01],
        nextHeader: 6, // TCP
        destinationPort: 443
    )
    let summary = PacketSummary(packet: packet)
    #expect(summary != nil)
    #expect(summary?.remoteHost == "2001:db8:0:0:0:0:0:1")
    #expect(summary?.remotePort == 443)
    #expect(summary?.transport == .tcp)
}

// MARK: - Edge Cases

@Test
func returnsNilForEmptyPacket() {
    #expect(PacketSummary(packet: Data()) == nil)
}

@Test
func returnsNilForTruncatedIPv4() {
    #expect(PacketSummary(packet: Data([0x45, 0x00])) == nil)
}

@Test
func returnsNilForTruncatedIPv6() {
    let shortPacket = Data([0x60] + [UInt8](repeating: 0, count: 10))
    #expect(PacketSummary(packet: shortPacket) == nil)
}

@Test
func returnsNilForUnsupportedIPVersion() {
    let packet = Data([0x30] + [UInt8](repeating: 0, count: 40))
    #expect(PacketSummary(packet: packet) == nil)
}

// MARK: - Helpers

private func buildIPv4Packet(
    destinationIP: [UInt8],
    protocol protocolNumber: UInt8,
    destinationPort: Int?
) -> Data {
    // Minimal IPv4 header (20 bytes, IHL=5)
    var header = [UInt8](repeating: 0, count: 20)
    header[0] = 0x45
    header[9] = protocolNumber
    header[12] = 10; header[13] = 0; header[14] = 0; header[15] = 1
    header[16] = destinationIP[0]
    header[17] = destinationIP[1]
    header[18] = destinationIP[2]
    header[19] = destinationIP[3]

    var packet = Data(header)

    if let port = destinationPort, (protocolNumber == 6 || protocolNumber == 17) {
        // Transport header: src_port(2) + dst_port(2)
        var transport = [UInt8](repeating: 0, count: protocolNumber == 6 ? 20 : 8)
        transport[0] = UInt8((12345 >> 8) & 0xFF)
        transport[1] = UInt8(12345 & 0xFF)
        transport[2] = UInt8((port >> 8) & 0xFF)
        transport[3] = UInt8(port & 0xFF)
        if protocolNumber == 6 {
            transport[12] = 0x50
        }
        packet.append(contentsOf: transport)
    }

    return packet
}

private func buildIPv6Packet(
    destinationIP: [UInt8],
    nextHeader: UInt8,
    destinationPort: Int
) -> Data {
    // IPv6 header (40 bytes)
    var header = [UInt8](repeating: 0, count: 40)
    header[0] = 0x60
    header[6] = nextHeader
    for i in 0..<16 {
        header[24 + i] = destinationIP[i]
    }

    var packet = Data(header)

    // TCP header (20 bytes)
    var transport = [UInt8](repeating: 0, count: 20)
    transport[0] = UInt8((12345 >> 8) & 0xFF)
    transport[1] = UInt8(12345 & 0xFF)
    transport[2] = UInt8((destinationPort >> 8) & 0xFF)
    transport[3] = UInt8(destinationPort & 0xFF)
    transport[12] = 0x50
    packet.append(contentsOf: transport)

    return packet
}
