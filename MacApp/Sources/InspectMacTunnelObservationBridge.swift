import Foundation
@preconcurrency import NetworkExtension

@MainActor
final class InspectMacTunnelObservationBridge {
    private var statusObserver: NSObjectProtocol?
    private var configurationObserver: NSObjectProtocol?

    func observe(
        manager: NETunnelProviderManager,
        onStatusChange: @escaping @MainActor () -> Void,
        onConfigurationChange: @escaping @MainActor () -> Void
    ) {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }

        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onStatusChange()
            }
        }

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNConfigurationChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onConfigurationChange()
            }
        }
    }
}
