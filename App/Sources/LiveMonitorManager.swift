import InspectCore
import Foundation
@preconcurrency import NetworkExtension
import Observation
import OSLog

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
    static let providerBundleIdentifier = "in.fourplex.Inspect.AppProxyExtension"
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
    private let logger = Logger(subsystem: "in.fourplex.Inspect", category: "LiveMonitorManager")

    func refresh() async {
        log("Refreshing tunnel manager state")
        do {
            let manager = try await loadOrCreateManager()
            self.manager = manager
            configureObservers(for: manager)
            updateState(from: manager)
            if desiredLiveMonitorEnabled == nil {
                desiredLiveMonitorEnabled = LiveMonitorTunnelState.isActive(for: manager.connection.status)
            }
            self.lastErrorMessage = nil
            log("Refresh complete. status=\(statusDescription(manager.connection.status)) configured=\(manager.isEnabled)")
        } catch {
            let normalized = normalize(error)
            self.lastErrorMessage = normalized.localizedDescription
            log("Refresh failed: \(normalized.localizedDescription)")
        }
    }

    func setLiveMonitorEnabled(_ enabled: Bool) async throws {
        log("setLiveMonitorEnabled(\(enabled))")
        desiredLiveMonitorEnabled = enabled
        if enabled {
            do {
                let manager = try await cachedOrLoadedManager()
                log("Loaded tunnel manager. currentStatus=\(statusDescription(manager.connection.status))")

                if needsConfiguration(manager) {
                    configure(manager)
                    log("Saving tunnel preferences")
                    try await saveToPreferences(manager)
                    log("Reloading tunnel preferences")
                    try await manager.loadFromPreferences()
                } else {
                    log("Tunnel manager already configured; skipping preference rewrite")
                }

                self.manager = manager
                configureObservers(for: manager)
                updateState(from: manager)
                try await reconcileDesiredStateIfNeeded(using: manager)
                lastErrorMessage = nil
                log("Live Monitor enabled. status=\(statusDescription(manager.connection.status)) configured=\(manager.isEnabled)")
            } catch {
                let normalized = normalize(error)
                lastErrorMessage = normalized.localizedDescription
                log("Enabling Live Monitor failed: \(normalized.localizedDescription)")
                throw normalized
            }
        } else {
            if manager == nil {
                log("No cached manager while disabling; reloading manager")
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
            log("Live Monitor disabled. status=\(statusDescription(status))")
        }
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await loadAllManagers()
        log("Loaded \(managers.count) tunnel manager(s) from preferences")
        if let manager = managers.first(where: matchesProvider) {
            log("Found existing Inspect tunnel manager")
            return manager
        }

        log("Creating new Inspect tunnel manager")
        return NETunnelProviderManager()
    }

    private func cachedOrLoadedManager() async throws -> NETunnelProviderManager {
        if let manager, matchesProvider(manager) {
            log("Using cached Inspect tunnel manager")
            return manager
        }

        return try await loadOrCreateManager()
    }

    private func loadAllManagers() async throws -> [NETunnelProviderManager] {
        try await NETunnelProviderManager.loadAllFromPreferences()
    }

    private func saveToPreferences(_ manager: NETunnelProviderManager) async throws {
        try await manager.saveToPreferences()
        log("Saved tunnel preferences successfully")
    }

    private func configure(_ manager: NETunnelProviderManager) {
        manager.localizedDescription = Self.localizedDescription

        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = Self.providerBundleIdentifier
        protocolConfiguration.serverAddress = "Inspect Live Monitor"

        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true
        log("Configured manager with providerBundleIdentifier=\(Self.providerBundleIdentifier)")
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

        return configuration.providerBundleIdentifier != Self.providerBundleIdentifier
    }

    private func matchesProvider(_ manager: NETunnelProviderManager) -> Bool {
        guard let configuration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return false
        }

        return configuration.providerBundleIdentifier == Self.providerBundleIdentifier
    }

    private func updateState(from manager: NETunnelProviderManager) {
        let currentStatus = manager.connection.status
        status = currentStatus
        isConfigured = manager.isEnabled && manager.protocolConfiguration != nil
        UserDefaults.standard.set(
            LiveMonitorTunnelState.isActive(for: currentStatus),
            forKey: Self.liveMonitorEnabledKey
        )
        log("Updated state. status=\(statusDescription(currentStatus)) configured=\(isConfigured)")
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
                log("VPN tunnel already active with status=\(statusDescription(currentStatus))")
            } else {
                log("VPN tunnel already inactive with status=\(statusDescription(currentStatus))")
            }
        case .waitForDisconnect:
            log("VPN tunnel is disconnecting; waiting for the next stable state")
        case .start:
            isReconcilingDesiredState = true
            defer { isReconcilingDesiredState = false }
            log("Starting VPN tunnel")
            try manager.connection.startVPNTunnel()
        case .stop:
            isReconcilingDesiredState = true
            defer { isReconcilingDesiredState = false }
            log("Stopping VPN tunnel")
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
                self.log("Received NEVPNStatusDidChange")
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
                self?.log("Received NEVPNConfigurationChange")
                await self?.refresh()
            }
        }
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        NSLog("[InspectApp] %@", message)
        InspectSharedLog.append(scope: "InspectApp", message: message)
    }
}
