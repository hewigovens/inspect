import Foundation

final class TunnelCore: @unchecked Sendable {
    func configureLogFile(path: String?) throws {
        guard let path, path.isEmpty == false else {
            return
        }

        try withCString(path) { cPath in
            try checkReturnCode(tunnel_core_set_log_file(cPath), operation: "set log file")
        }
    }

    func setTunFileDescriptor(_ fileDescriptor: Int32) throws {
        try checkReturnCode(
            tunnel_core_set_tun_fd(fileDescriptor),
            operation: "set tun fd"
        )
    }

    func start(configuration: TunnelCoreStartConfiguration) throws {
        let configJSON = try String(decoding: JSONEncoder().encode(configuration), as: UTF8.self)
        try withCString(configJSON) { configCString in
            try checkReturnCode(
                tunnel_core_start(configCString),
                operation: "start core"
            )
        }
    }

    func startLiveLoop() throws {
        try checkReturnCode(
            tunnel_core_start_live_loop(),
            operation: "start live loop"
        )
    }

    func stop() {
        tunnel_core_stop()
    }

    func stats() throws -> TunnelCoreStats {
        var raw = InspectTunnelCoreStats(tx_packets: 0, tx_bytes: 0, rx_packets: 0, rx_bytes: 0)
        try checkReturnCode(tunnel_core_get_stats(&raw), operation: "read stats")
        return TunnelCoreStats(
            txPackets: Int(raw.tx_packets),
            txBytes: Int(raw.tx_bytes),
            rxPackets: Int(raw.rx_packets),
            rxBytes: Int(raw.rx_bytes)
        )
    }

    func drainObservations() throws -> [TunnelCoreObservation] {
        guard let pointer = tunnel_core_drain_observations_json() else {
            return []
        }

        let payload = String(cString: pointer)
        guard payload.isEmpty == false,
              let data = payload.data(using: .utf8) else {
            return []
        }

        return try JSONDecoder().decode([TunnelCoreObservation].self, from: data)
    }

    var version: String {
        String(cString: tunnel_core_version())
    }

    private func checkReturnCode(_ code: Int32, operation: String) throws {
        guard code == 0 else {
            throw TunnelCoreError.operationFailed(
                operation: operation,
                message: lastErrorMessage() ?? "unknown error"
            )
        }
    }

    private func lastErrorMessage() -> String? {
        guard let pointer = tunnel_core_last_error_message() else {
            return nil
        }

        return String(cString: pointer)
    }
}

private func withCString<Result>(
    _ string: String,
    body: (UnsafePointer<CChar>) throws -> Result
) throws -> Result {
    try string.withCString { pointer in
        try body(pointer)
    }
}

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

private enum TunnelCoreError: LocalizedError {
    case operationFailed(operation: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .operationFailed(operation, message):
            return "Tunnel core failed to \(operation): \(message)"
        }
    }
}
