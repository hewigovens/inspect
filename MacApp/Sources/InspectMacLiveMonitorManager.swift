import InspectCore
import Foundation
@preconcurrency import NetworkExtension
import Observation

enum InspectMacLiveMonitorManagerError: LocalizedError {
    case capabilityMissing
    case configurationUnavailable

    var errorDescription: String? {
        switch self {
        case .capabilityMissing:
            return "Packet Tunnel capability is unavailable for this signing setup. Enable Network Extensions (Packet Tunnel) for the macOS app and extension, then refresh signing."
        case .configurationUnavailable:
            return "Unable to create or load the Inspect Packet Tunnel configuration."
        }
    }
}

@MainActor
@Observable
final class InspectMacLiveMonitorManager {
    private static let liveMonitorEnabledKey = "inspect.monitor.enabled.v1"

    var status: NEVPNStatus = .invalid
    var lastErrorMessage: String?
    var actionMessage: String?
    var isActivatingExtension = false
    private(set) var isConfigured = false

    @ObservationIgnored
    private var manager: NETunnelProviderManager?
    @ObservationIgnored
    private var desiredLiveMonitorEnabled: Bool?
    @ObservationIgnored
    private var isReconcilingDesiredState = false
    @ObservationIgnored
    private let tunnelService = InspectMacTunnelManagerService(
        profile: InspectMacTunnelDefaults.verificationProfile
    )
    @ObservationIgnored
    private let observationBridge = InspectMacTunnelObservationBridge()
    @ObservationIgnored
    private let systemExtensionActivator = MacSystemExtensionActivator()
    @ObservationIgnored
    private let logger = InspectRuntimeLogger(
        category: "LiveMonitorManager",
        scope: "InspectMac"
    )

    init() {
        systemExtensionActivator.onApprovalRequired = { [weak self] in
            Task { @MainActor [weak self] in
                self?.actionMessage = "System Settings approval is required before the extension can finish activating."
            }
        }
    }

    func refresh() async {
        logger.verbose("Refreshing tunnel manager state")
        do {
            let manager = try await tunnelService.loadOrCreateManager()
            self.manager = manager
            configureObservers(for: manager)
            updateState(from: manager)
            if desiredLiveMonitorEnabled == nil {
                desiredLiveMonitorEnabled = LiveMonitorTunnelState.isActive(for: manager.connection.status)
            }
            lastErrorMessage = nil
            logger.verbose("Refresh complete. status=\(statusDescription(manager.connection.status)) configured=\(manager.isEnabled)")
        } catch {
            let normalized = normalize(error)
            lastErrorMessage = normalized.localizedDescription
            logger.critical("Refresh failed: \(normalized.localizedDescription)")
        }
    }

    func installProfile() async {
        logger.verbose("Installing or updating packet tunnel profile")
        do {
            let manager = try await tunnelService.loadOrCreateManager()
            try await tunnelService.configureIfNeeded(manager)
            self.manager = manager
            configureObservers(for: manager)
            updateState(from: manager)
            actionMessage = "VPN profile saved. Open System Settings > VPN if macOS prompts for approval."
            lastErrorMessage = nil
            logger.verbose("Install profile complete. status=\(statusDescription(manager.connection.status)) configured=\(manager.isEnabled)")
        } catch {
            let normalized = normalize(error)
            lastErrorMessage = normalized.localizedDescription
            logger.critical("Install profile failed: \(normalized.localizedDescription)")
        }
    }

    func setLiveMonitorEnabled(_ enabled: Bool) async throws {
        logger.verbose("setLiveMonitorEnabled(\(enabled))")
        desiredLiveMonitorEnabled = enabled

        if enabled {
            do {
                let manager = try await cachedOrLoadedManager()
                if InspectMacTunnelPreferences.needsConfiguration(
                    manager,
                    localizedDescription: tunnelService.profile.localizedDescription,
                    providerBundleIdentifier: tunnelService.profile.providerBundleIdentifier
                ) {
                    try await tunnelService.configureIfNeeded(manager)
                }

                self.manager = manager
                configureObservers(for: manager)
                updateState(from: manager)
                try await reconcileDesiredStateIfNeeded(using: manager)
                actionMessage = "Live Monitor start requested."
                lastErrorMessage = nil
                logger.verbose("Enable flow finished. status=\(statusDescription(manager.connection.status)) configured=\(manager.isEnabled)")
            } catch {
                let normalized = normalize(error)
                lastErrorMessage = normalized.localizedDescription
                logger.critical("Enable flow failed: \(normalized.localizedDescription)")
                throw normalized
            }
        } else {
            if manager == nil {
                manager = try? await tunnelService.loadOrCreateManager()
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

            actionMessage = "Live Monitor stop requested."
            lastErrorMessage = nil
            logger.verbose("Disable flow finished. status=\(statusDescription(status))")
        }
    }

    func activateSystemExtension() async {
        guard isActivatingExtension == false else {
            return
        }

        isActivatingExtension = true
        actionMessage = "Submitting system extension activation request."
        defer { isActivatingExtension = false }

        do {
            try await systemExtensionActivator.activate(
                identifier: tunnelService.profile.providerBundleIdentifier
            )
            actionMessage = "System extension activation finished."
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.critical("System extension activation failed: \(error.localizedDescription)")
        }
    }

    func openSystemSettings() {
        actionMessage = "Opening System Settings."
        InspectMacSystemSettingsNavigator.openVPNSettings { [weak self] error in
            guard let self else {
                return
            }

            if let error {
                self.lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func cachedOrLoadedManager() async throws -> NETunnelProviderManager {
        if let manager, matchesProvider(manager) {
            return manager
        }

        return try await tunnelService.loadOrCreateManager()
    }

    private func matchesProvider(_ manager: NETunnelProviderManager) -> Bool {
        InspectMacTunnelPreferences.matchesProvider(
            manager,
            providerBundleIdentifier: tunnelService.profile.providerBundleIdentifier
        )
    }

    private func updateState(from manager: NETunnelProviderManager) {
        let currentStatus = manager.connection.status
        status = currentStatus
        isConfigured = manager.isEnabled && manager.protocolConfiguration != nil
        UserDefaults.standard.set(
            LiveMonitorTunnelState.isActive(for: currentStatus),
            forKey: Self.liveMonitorEnabledKey
        )
    }

    private func reconcileDesiredStateIfNeeded(using manager: NETunnelProviderManager) async throws {
        guard isReconcilingDesiredState == false else {
            return
        }
        guard let desiredLiveMonitorEnabled else {
            return
        }

        switch LiveMonitorTunnelState.action(
            for: manager.connection.status,
            desiredEnabled: desiredLiveMonitorEnabled
        ) {
        case .none, .waitForDisconnect:
            return
        case .start:
            isReconcilingDesiredState = true
            defer { isReconcilingDesiredState = false }
            try manager.connection.startVPNTunnel()
        case .stop:
            isReconcilingDesiredState = true
            defer { isReconcilingDesiredState = false }
            manager.connection.stopVPNTunnel()
        }
    }

    private func configureObservers(for manager: NETunnelProviderManager) {
        observationBridge.observe(
            manager: manager,
            onStatusChange: { [weak self] in
                self?.updateState(from: manager)
            },
            onConfigurationChange: { [weak self] in
                guard let self else {
                    return
                }

                Task {
                    await self.refresh()
                }
            }
        )
    }

    private func normalize(_ error: Error) -> Error {
        let message = error.localizedDescription.lowercased()

        if message.contains("not entitled") || message.contains("permission denied") {
            return InspectMacLiveMonitorManagerError.capabilityMissing
        }

        if message.contains("failed to load preferences")
            || message.contains("unable to load")
            || message.contains("unable to save") {
            return InspectMacLiveMonitorManagerError.configurationUnavailable
        }

        return error
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
}
