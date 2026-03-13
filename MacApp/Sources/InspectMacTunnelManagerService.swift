import Foundation
@preconcurrency import NetworkExtension

@MainActor
final class InspectMacTunnelManagerService {
    let profile: InspectMacTunnelProfile

    init(profile: InspectMacTunnelProfile) {
        self.profile = profile
    }

    func loadOrCreateManager() async throws -> NETunnelProviderManager {
        try await InspectMacTunnelPreferences.loadOrCreateManager(
            matching: profile.providerBundleIdentifier
        )
    }

    func configureIfNeeded(_ manager: NETunnelProviderManager) async throws {
        guard InspectMacTunnelPreferences.needsConfiguration(
            manager,
            localizedDescription: profile.localizedDescription,
            providerBundleIdentifier: profile.providerBundleIdentifier
        ) else {
            return
        }

        InspectMacTunnelPreferences.configure(
            manager,
            localizedDescription: profile.localizedDescription,
            providerBundleIdentifier: profile.providerBundleIdentifier,
            serverAddress: profile.serverAddress
        )
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
    }

    func describe(_ manager: NETunnelProviderManager) -> String {
        let providerBundleIdentifier: String
        let serverAddress: String
        if let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol {
            providerBundleIdentifier = configuration.providerBundleIdentifier ?? "nil"
            serverAddress = configuration.serverAddress ?? "nil"
        } else {
            providerBundleIdentifier = "nil"
            serverAddress = "nil"
        }

        let connectedDate = manager.connection.connectedDate?.description ?? "nil"
        return "localizedDescription=\(manager.localizedDescription ?? "nil") enabled=\(manager.isEnabled) status=\(manager.connection.status.description) providerBundleIdentifier=\(providerBundleIdentifier) serverAddress=\(serverAddress) connectedDate=\(connectedDate)"
    }
}
