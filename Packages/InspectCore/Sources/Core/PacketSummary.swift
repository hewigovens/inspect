import Foundation

struct PacketSummary {
    let transport: TLSFlowTransport
    let remoteHost: String
    let remotePort: Int?
    let serverName: String?

    var isLikelyTLSPort: Bool {
        guard let remotePort else {
            return false
        }

        switch remotePort {
        case 443, 8443, 9443:
            return true
        default:
            return false
        }
    }

    init?(packet: Data) {
        let bytes = [UInt8](packet)
        guard let firstByte = bytes.first else {
            return nil
        }

        let ipVersion = firstByte >> 4
        switch ipVersion {
        case 4:
            guard bytes.count >= 20 else {
                return nil
            }

            let headerLength = Int(firstByte & 0x0F) * 4
            guard bytes.count >= headerLength else {
                return nil
            }

            let protocolNumber = bytes[9]
            let destinationAddress = [
                String(bytes[16]),
                String(bytes[17]),
                String(bytes[18]),
                String(bytes[19]),
            ].joined(separator: ".")

            transport = Self.transport(for: protocolNumber)
            remoteHost = destinationAddress
            remotePort = Self.destinationPort(
                from: bytes,
                protocolNumber: protocolNumber,
                transportOffset: headerLength
            )
            serverName = Self.serverName(
                from: bytes,
                protocolNumber: protocolNumber,
                transportOffset: headerLength
            )

        case 6:
            guard bytes.count >= 40 else {
                return nil
            }

            let protocolNumber = bytes[6]
            let destinationSlice = bytes[24 ..< 40]

            transport = Self.transport(for: protocolNumber)
            remoteHost = Self.ipv6String(from: destinationSlice)
            remotePort = Self.destinationPort(
                from: bytes,
                protocolNumber: protocolNumber,
                transportOffset: 40
            )
            serverName = Self.serverName(
                from: bytes,
                protocolNumber: protocolNumber,
                transportOffset: 40
            )

        default:
            return nil
        }
    }

    private static func transport(for protocolNumber: UInt8) -> TLSFlowTransport {
        switch protocolNumber {
        case IPProtocol.tcp:
            return .tcp
        case IPProtocol.udp:
            return .udp
        default:
            return .unknown
        }
    }

    private static func destinationPort(from bytes: [UInt8], protocolNumber: UInt8, transportOffset: Int) -> Int? {
        guard protocolNumber == IPProtocol.tcp || protocolNumber == IPProtocol.udp,
              bytes.count >= transportOffset + 4
        else {
            return nil
        }

        let upper = UInt16(bytes[transportOffset + 2]) << 8
        let lower = UInt16(bytes[transportOffset + 3])
        return Int(upper | lower)
    }

    private static func serverName(from bytes: [UInt8], protocolNumber: UInt8, transportOffset: Int) -> String? {
        guard protocolNumber == IPProtocol.tcp,
              bytes.count >= transportOffset + 20
        else {
            return nil
        }

        let tcpHeaderLength = Int((bytes[transportOffset + 12] >> 4) & 0x0F) * 4
        guard tcpHeaderLength >= 20 else {
            return nil
        }

        let payloadOffset = transportOffset + tcpHeaderLength
        guard payloadOffset < bytes.count else {
            return nil
        }

        let payload = Array(bytes[payloadOffset...])
        return TLSClientHelloSNIExtractor.serverName(from: payload)
    }

    private static func ipv6String(from bytes: ArraySlice<UInt8>) -> String {
        guard bytes.count == 16 else {
            return "0:0:0:0:0:0:0:0"
        }

        var segments: [String] = []
        var index = bytes.startIndex

        while index < bytes.endIndex {
            let next = bytes.index(index, offsetBy: 1)
            let segmentValue = (UInt16(bytes[index]) << 8) | UInt16(bytes[next])
            segments.append(String(segmentValue, radix: 16))
            index = bytes.index(index, offsetBy: 2)
        }

        return segments.joined(separator: ":")
    }
}
