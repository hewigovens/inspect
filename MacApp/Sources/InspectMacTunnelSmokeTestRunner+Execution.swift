import Darwin
import Foundation
import InspectCore
@preconcurrency import NetworkExtension

extension InspectMacTunnelSmokeTestRunner {
    func run() async {
        phase = .running
        var exitCode = 0
        var manager: NETunnelProviderManager?

        defer {
            task = nil
            if configuration.autoQuit {
                let delay = DispatchTime.now() + .milliseconds(500)
                DispatchQueue.main.asyncAfter(deadline: delay) {
                    fflush(stdout)
                    fflush(stderr)
                    exit(Int32(exitCode))
                }
            }
        }

        do {
            transcriptStore.reset()
            InspectLogConfiguration.set(.verbose)
            InspectSharedLog.reset()
            append("Smoke test started")
            append("Using probe URL \(configuration.probeURL.absoluteString)")

            manager = try await tunnelController.prepareManager()
            guard let manager else {
                throw InspectMacTunnelSmokeTestError.managerUnavailable
            }

            append("Starting packet tunnel")
            try manager.connection.startVPNTunnel()
            try await tunnelController.waitForConnected(manager) { [weak self] message in
                self?.append(message)
            }

            let probeResponse = try await tunnelController.runProbeRequest(to: configuration.probeURL)
            append("HTTPS probe succeeded. status=\(probeResponse.statusCode ?? 0) bytes=\(probeResponse.byteCount)")
            append("Waiting for tunnel logs to flush")
            try await Task.sleep(nanoseconds: 1_000_000_000)

            if let logFileURL = InspectSharedLog.logFileURL() {
                append("Tunnel log path: \(logFileURL.path)")
            } else {
                append("Tunnel log path unavailable for app group \(InspectSharedContainer.appGroupIdentifier)")
            }

            if let tail = InspectSharedLog.readTail(maxBytes: 16 * 1024) {
                append("Tunnel log tail:\n\(tail)")
            } else {
                append("Tunnel log is empty")
            }

            append("Stopping packet tunnel")
            manager.connection.stopVPNTunnel()
            try await tunnelController.waitForDisconnected(manager) { [weak self] message in
                self?.append(message)
            }

            phase = .succeeded
            append("Smoke test completed successfully")
        } catch {
            exitCode = 1
            phase = .failed
            append("Smoke test failed: \(error.localizedDescription)")

            if let manager {
                manager.connection.stopVPNTunnel()
            }
        }
    }

    func append(_ line: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] \(line)"
        print(formatted)
        transcriptStore.append(formatted + "\n")
        if transcript.isEmpty {
            transcript = formatted
        } else {
            transcript += "\n" + formatted
        }
    }
}
