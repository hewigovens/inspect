import Foundation
@preconcurrency import NetworkExtension

@MainActor
final class InspectMacTunnelSmokeTestController {
    private let tunnelService = InspectMacTunnelManagerService(
        profile: InspectMacTunnelDefaults.smokeTestProfile
    )

    func prepareManager() async throws -> NETunnelProviderManager {
        let manager = try await tunnelService.loadOrCreateManager()
        try await tunnelService.configureIfNeeded(manager)

        return manager
    }

    func waitForConnected(
        _ manager: NETunnelProviderManager,
        progress: @escaping @MainActor (String) -> Void
    ) async throws {
        try await waitForStatus(
            manager,
            expected: .connected,
            timeoutNanoseconds: 45_000_000_000,
            progress: progress
        )
    }

    func waitForDisconnected(
        _ manager: NETunnelProviderManager,
        progress: @escaping @MainActor (String) -> Void
    ) async throws {
        try await waitForStatus(
            manager,
            expected: .disconnected,
            timeoutNanoseconds: 15_000_000_000,
            progress: progress
        )
    }

    func runProbeRequest(to url: URL) async throws -> (statusCode: Int?, byteCount: Int) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20

        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        return (statusCode, data.count)
    }

    private func waitForStatus(
        _ manager: NETunnelProviderManager,
        expected: NEVPNStatus,
        timeoutNanoseconds: UInt64,
        progress: @escaping @MainActor (String) -> Void
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + .nanoseconds(Int64(timeoutNanoseconds))
        var lastStatus: NEVPNStatus?

        while clock.now < deadline {
            let status = manager.connection.status
            if status != lastStatus {
                lastStatus = status
                progress("Tunnel status changed to \(status.description)")
            }

            if status == expected {
                return
            }

            try await Task.sleep(nanoseconds: 500_000_000)
        }

        throw InspectMacTunnelSmokeTestError.statusTimeout(expected: expected.description)
    }
}

enum InspectMacTunnelSmokeTestError: LocalizedError {
    case managerUnavailable
    case statusTimeout(expected: String)

    var errorDescription: String? {
        switch self {
        case .managerUnavailable:
            return "Unable to create or reload the packet tunnel manager."
        case let .statusTimeout(expected):
            return "Timed out waiting for tunnel status \(expected)."
        }
    }
}
