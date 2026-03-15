import Foundation
@preconcurrency import NetworkExtension

enum InspectMacTunnelPreferences {
    static func loadOrCreateManager(
        matching providerBundleIdentifier: String
    ) async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let manager = managers.first(where: { matchesProvider($0, providerBundleIdentifier: providerBundleIdentifier) }) {
            return manager
        }

        return NETunnelProviderManager()
    }

    static func configure(
        _ manager: NETunnelProviderManager,
        localizedDescription: String,
        providerBundleIdentifier: String,
        serverAddress: String
    ) {
        manager.localizedDescription = localizedDescription

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = providerBundleIdentifier
        protocolConfiguration.serverAddress = serverAddress

        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true
    }

    static func needsConfiguration(
        _ manager: NETunnelProviderManager,
        localizedDescription: String,
        providerBundleIdentifier: String
    ) -> Bool {
        guard manager.isEnabled else {
            return true
        }

        guard manager.localizedDescription == localizedDescription else {
            return true
        }

        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return true
        }

        return configuration.providerBundleIdentifier != providerBundleIdentifier
    }

    static func matchesProvider(
        _ manager: NETunnelProviderManager,
        providerBundleIdentifier: String
    ) -> Bool {
        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return false
        }

        return configuration.providerBundleIdentifier == providerBundleIdentifier
    }
}
