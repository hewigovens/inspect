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

    func takeExitCode() throws -> Int32? {
        var code: Int32 = 0
        let result = tunnel_core_take_exit_code(&code)
        if result < 0 {
            try checkReturnCode(result, operation: "read exit code")
        }
        return result == 0 ? nil : code
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
