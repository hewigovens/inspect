import Foundation

struct TunnelCoreStartConfiguration: Encodable {
    let ipv4Address: String
    let ipv6Address: String
    let dnsAddress: String
    let fakeIpRange: String
    let mtu: Int
    let monitorEnabled: Bool
    let verboseLoggingEnabled: Bool
}

struct TunnelCoreStats: Sendable, Equatable {
    let txPackets: Int
    let txBytes: Int
    let rxPackets: Int
    let rxBytes: Int
}

enum TunnelCoreTransport: String, Decodable, Sendable {
    case tcp
    case udp
    case unknown
}

struct TunnelCoreObservation: Decodable, Sendable {
    let transport: String
    let remoteHost: String
    let remotePort: Int?
    let serverName: String?
    let capturedCertificateChainDerHex: [String]?

    var transportValue: TunnelCoreTransport {
        TunnelCoreTransport(rawValue: transport) ?? .unknown
    }

    func decodedCertificateChainDER() -> [Data]? {
        capturedCertificateChainDerHex?.compactMap(Self.decodeHex)
    }

    private static func decodeHex(_ value: String) -> Data? {
        let length = value.count
        guard length.isMultiple(of: 2) else {
            return nil
        }

        var data = Data(capacity: length / 2)
        var index = value.startIndex
        while index < value.endIndex {
            let nextIndex = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}
