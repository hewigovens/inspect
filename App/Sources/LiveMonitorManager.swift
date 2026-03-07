import InspectCore
import Foundation
@preconcurrency import NetworkExtension
import Observation

enum LiveMonitorManagerError: LocalizedError {
    case capabilityMissing
    case configurationUnavailable

    var errorDescription: String? {
        switch self {
        case .capabilityMissing:
            return "Packet Tunnel capability is unavailable for this provisioning profile. Enable Network Extensions (Packet Tunnel) for the app and extension IDs, then refresh profiles."
        case .configurationUnavailable:
            return "Unable to create or load the Packet Tunnel configuration."
        }
    }
}

@MainActor
@Observable
final class LiveMonitorManager {
    static let tunnelProviderBundleIdentifier = "in.fourplex.Inspect.PacketTunnelExtension"
    static let localizedDescription = "Inspect Live Monitor"
    private static let liveMonitorEnabledKey = "inspect.monitor.enabled.v1"

    var status: NEVPNStatus = .invalid
    var lastErrorMessage: String?
    private(set) var isConfigured = false

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var configurationObserver: NSObjectProtocol?
    private var desiredLiveMonitorEnabled: Bool?
    private var isReconcilingDesiredState = false
    private let logger = InspectRuntimeLogger(
        category: "LiveMonitorManager",
        scope: "InspectApp"
    )

    func refresh() async {
        logger.verbose("Refreshing tunnel manager state")
        do {
            let manager = try await loadOrCreateManager()
            self.manager = manager
            configureObservers(for: manager)
            updateState(from: manager)
            if desiredLiveMonitorEnabled == nil {
                desiredLiveMonitorEnabled = LiveMonitorTunnelState.isActive(for: manager.connection.status)
            }
            self.lastErrorMessage = nil
            logger.verbose("Refresh complete. status=\(statusDescription(manager.connection.status)) configured=\(manager.isEnabled)")
        } catch {
            let normalized = normalize(error)
            self.lastErrorMessage = normalized.localizedDescription
            logger.critical("Refresh failed: \(normalized.localizedDescription)")
        }
    }

    func setLiveMonitorEnabled(_ enabled: Bool) async throws {
        logger.verbose("setLiveMonitorEnabled(\(enabled))")
        desiredLiveMonitorEnabled = enabled
        if enabled {
            do {
                let manager = try await cachedOrLoadedManager()
                logger.verbose("Loaded tunnel manager. currentStatus=\(statusDescription(manager.connection.status))")

                if needsConfiguration(manager) {
                    configure(manager)
                    logger.verbose("Saving tunnel preferences")
                    try await saveToPreferences(manager)
                    logger.verbose("Reloading tunnel preferences")
                    try await manager.loadFromPreferences()
                } else {
                    logger.verbose("Tunnel manager already configured; skipping preference rewrite")
                }

                self.manager = manager
                configureObservers(for: manager)
                updateState(from: manager)
                try await reconcileDesiredStateIfNeeded(using: manager)
                lastErrorMessage = nil
                logger.verbose("Live Monitor enabled. status=\(statusDescription(manager.connection.status)) configured=\(manager.isEnabled)")
            } catch {
                let normalized = normalize(error)
                lastErrorMessage = normalized.localizedDescription
                logger.critical("Enabling Live Monitor failed: \(normalized.localizedDescription)")
                throw normalized
            }
        } else {
            if manager == nil {
                logger.verbose("No cached manager while disabling; reloading manager")
                manager = try? await loadOrCreateManager()
                if let manager {
                    configureObservers(for: manager)
                }
            }

            if let manager {
                try? await reconcileDesiredStateIfNeeded(using: manager)
                updateState(from: manager)
            } else {
                status = .disconnected
            }

            lastErrorMessage = nil
            logger.verbose("Live Monitor disabled. status=\(statusDescription(status))")
        }
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await loadAllManagers()
        logger.verbose("Loaded \(managers.count) tunnel manager(s) from preferences")
        if let manager = managers.first(where: matchesProvider) {
            logger.verbose("Found existing Inspect tunnel manager")
            return manager
        }

        logger.verbose("Creating new Inspect tunnel manager")
        return NETunnelProviderManager()
    }

    private func cachedOrLoadedManager() async throws -> NETunnelProviderManager {
        if let manager, matchesProvider(manager) {
            logger.verbose("Using cached Inspect tunnel manager")
            return manager
        }

        return try await loadOrCreateManager()
    }

    private func loadAllManagers() async throws -> [NETunnelProviderManager] {
        try await NETunnelProviderManager.loadAllFromPreferences()
    }

    private func saveToPreferences(_ manager: NETunnelProviderManager) async throws {
        try await manager.saveToPreferences()
        logger.verbose("Saved tunnel preferences successfully")
    }

    private func configure(_ manager: NETunnelProviderManager) {
        manager.localizedDescription = Self.localizedDescription

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = Self.tunnelProviderBundleIdentifier
        protocolConfiguration.serverAddress = "Inspect Live Monitor"

        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true
        logger.verbose("Configured manager with providerBundleIdentifier=\(Self.tunnelProviderBundleIdentifier)")
    }

    private func needsConfiguration(_ manager: NETunnelProviderManager) -> Bool {
        guard manager.isEnabled else {
            return true
        }

        guard manager.localizedDescription == Self.localizedDescription else {
            return true
        }

        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return true
        }

        return configuration.providerBundleIdentifier != Self.tunnelProviderBundleIdentifier
    }

    private func matchesProvider(_ manager: NETunnelProviderManager) -> Bool {
        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return false
        }

        return configuration.providerBundleIdentifier == Self.tunnelProviderBundleIdentifier
    }

    private func updateState(from manager: NETunnelProviderManager) {
        let currentStatus = manager.connection.status
        status = currentStatus
        isConfigured = manager.isEnabled && manager.protocolConfiguration != nil
        UserDefaults.standard.set(
            LiveMonitorTunnelState.isActive(for: currentStatus),
            forKey: Self.liveMonitorEnabledKey
        )
        logger.verbose("Updated state. status=\(statusDescription(currentStatus)) configured=\(isConfigured)")
    }

    private func reconcileDesiredStateIfNeeded(using manager: NETunnelProviderManager) async throws {
        guard isReconcilingDesiredState == false else {
            return
        }
        guard let desiredLiveMonitorEnabled else {
            return
        }

        let currentStatus = manager.connection.status
        switch LiveMonitorTunnelState.action(for: currentStatus, desiredEnabled: desiredLiveMonitorEnabled) {
        case .none:
            if desiredLiveMonitorEnabled {
                logger.verbose("VPN tunnel already active with status=\(statusDescription(currentStatus))")
            } else {
                logger.verbose("VPN tunnel already inactive with status=\(statusDescription(currentStatus))")
            }
        case .waitForDisconnect:
            logger.verbose("VPN tunnel is disconnecting; waiting for the next stable state")
        case .start:
            isReconcilingDesiredState = true
            defer { isReconcilingDesiredState = false }
            logger.verbose("Starting VPN tunnel")
            try manager.connection.startVPNTunnel()
        case .stop:
            isReconcilingDesiredState = true
            defer { isReconcilingDesiredState = false }
            logger.verbose("Stopping VPN tunnel")
            manager.connection.stopVPNTunnel()
        }
    }

    private func statusDescription(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid:
            return "Invalid"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reasserting"
        case .disconnecting:
            return "Disconnecting"
        @unknown default:
            return "Unknown"
        }
    }

    private func normalize(_ error: Error) -> Error {
        let message = error.localizedDescription.lowercased()

        if message.contains("not entitled") || message.contains("permission denied") {
            return LiveMonitorManagerError.capabilityMissing
        }

        if message.contains("failed to load preferences")
            || message.contains("unable to load")
            || message.contains("unable to save") {
            return LiveMonitorManagerError.configurationUnavailable
        }

        return error
    }

    private func configureObservers(for manager: NETunnelProviderManager) {
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
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let manager = self.manager else {
                    return
                }
                self.logger.verbose("Received NEVPNStatusDidChange")
                self.updateState(from: manager)
                try? await self.reconcileDesiredStateIfNeeded(using: manager)
            }
        }

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logger.verbose("Received NEVPNConfigurationChange")
                await self?.refresh()
            }
        }
    }
}
