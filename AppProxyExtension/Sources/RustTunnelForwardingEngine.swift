import Foundation
import InspectCore
import OSLog

final class RustTunnelForwardingEngine: InspectTunnelForwardingEngine, @unchecked Sendable {
    let displayName = "RustCore"
    let requiresLocalSocksRelay = false

    private let logger: Logger
    private let stateQueue = DispatchQueue(label: "in.fourplex.Inspect.PacketTunnel.RustCore")
    private var isRunning = false

    init(logger: Logger) {
        self.logger = logger
    }

    func start(
        configuration: InspectTunnelForwardingConfiguration,
        exitHandler: @escaping @Sendable (Int32) -> Void
    ) throws {
        _ = exitHandler

        let shouldStart = stateQueue.sync { () -> Bool in
            guard isRunning == false else {
                return false
            }

            isRunning = true
            return true
        }

        guard shouldStart else {
            return
        }

        do {
            if let logFilePath = InspectSharedLog.logFileURL()?.path {
                try withCString(logFilePath) { path in
                    try checkReturnCode(
                        inspect_tunnel_core_set_log_file(path),
                        operation: "set log file"
                    )
                }
            }

            try checkReturnCode(
                inspect_tunnel_core_set_tun_fd(configuration.tunFileDescriptor),
                operation: "set tun fd"
            )

            let payload = RustTunnelCoreStartConfiguration(
                ipv4Address: configuration.ipv4Address,
                ipv6Address: configuration.ipv6Address,
                dnsAddress: configuration.dnsAddress,
                fakeIpRange: configuration.fakeIPAddressRange,
                mtu: configuration.mtu,
                monitorEnabled: configuration.monitorEnabled
            )
            let configJSON = try String(decoding: JSONEncoder().encode(payload), as: UTF8.self)
            try withCString(configJSON) { configCString in
                try checkReturnCode(
                    inspect_tunnel_core_start(configCString),
                    operation: "start core"
                )
            }
            try checkReturnCode(
                inspect_tunnel_core_start_live_loop(),
                operation: "start live loop"
            )

            log("Started Rust tunnel core version=\(coreVersion())")
        } catch {
            stateQueue.sync {
                isRunning = false
            }
            throw error
        }
    }

    func stop() {
        let shouldStop = stateQueue.sync { () -> Bool in
            guard isRunning else {
                return false
            }

            isRunning = false
            return true
        }

        guard shouldStop else {
            return
        }

        inspect_tunnel_core_stop()
        log("Stopped Rust tunnel core")
    }

    func stats() -> InspectTunnelForwardingStats {
        var raw = InspectTunnelCoreStats(tx_packets: 0, tx_bytes: 0, rx_packets: 0, rx_bytes: 0)
        let result = inspect_tunnel_core_get_stats(&raw)
        guard result == 0 else {
            log("Failed to read Rust tunnel core stats: \(lastErrorMessage() ?? "unknown error")")
            return InspectTunnelForwardingStats(txPackets: 0, txBytes: 0, rxPackets: 0, rxBytes: 0)
        }

        return InspectTunnelForwardingStats(
            txPackets: Int(raw.tx_packets),
            txBytes: Int(raw.tx_bytes),
            rxPackets: Int(raw.rx_packets),
            rxBytes: Int(raw.rx_bytes)
        )
    }

    func drainObservations() -> [TLSFlowObservation] {
        guard let pointer = inspect_tunnel_core_drain_observations_json() else {
            return []
        }

        let payload = String(cString: pointer)
        guard payload.isEmpty == false,
              let data = payload.data(using: .utf8) else {
            return []
        }

        do {
            let observations = try JSONDecoder().decode([RustTunnelCoreObservation].self, from: data)
            return observations.map(\.tlsFlowObservation)
        } catch {
            log("Failed to decode Rust tunnel observations: \(error.localizedDescription)")
            return []
        }
    }

    private func checkReturnCode(_ code: Int32, operation: String) throws {
        guard code == 0 else {
            throw RustTunnelForwardingEngineError.operationFailed(
                operation: operation,
                message: lastErrorMessage() ?? "unknown error"
            )
        }
    }

    private func lastErrorMessage() -> String? {
        guard let pointer = inspect_tunnel_core_last_error_message() else {
            return nil
        }

        return String(cString: pointer)
    }

    private func coreVersion() -> String {
        String(cString: inspect_tunnel_core_version())
    }

    private func withCString<Result>(
        _ string: String,
        body: (UnsafePointer<CChar>) throws -> Result
    ) throws -> Result {
        try string.withCString { pointer in
            try body(pointer)
        }
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        NSLog("[InspectRust] %@", message)
        InspectSharedLog.append(scope: "InspectRust", message: message)
    }
}

private struct RustTunnelCoreStartConfiguration: Encodable {
    let ipv4Address: String
    let ipv6Address: String
    let dnsAddress: String
    let fakeIpRange: String
    let mtu: Int
    let monitorEnabled: Bool
}

private struct RustTunnelCoreObservation: Decodable {
    let transport: String
    let remoteHost: String
    let remotePort: Int?
    let serverName: String?
    let capturedCertificateChainDerHex: [String]?

    var tlsFlowObservation: TLSFlowObservation {
        TLSFlowObservation(
            source: .networkExtension,
            transport: transportValue,
            remoteHost: remoteHost,
            remotePort: remotePort,
            serverName: serverName,
            capturedCertificateChainDER: capturedCertificateChainDerHex?.compactMap(Self.decodeHex)
        )
    }

    private var transportValue: TLSFlowTransport {
        switch transport {
        case "tcp":
            return .tcp
        case "udp":
            return .udp
        default:
            return .unknown
        }
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

private enum RustTunnelForwardingEngineError: LocalizedError {
    case operationFailed(operation: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .operationFailed(operation, message):
            return "Rust tunnel core failed to \(operation): \(message)"
        }
    }
}
