import InspectCore
import InspectKit
import Foundation
@preconcurrency import NetworkExtension
import Observation

@MainActor
@Observable
final class InspectMacLiveMonitorManager {
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
            updateState(from: manager, preservesActiveStatus: true)
            if desiredLiveMonitorEnabled == nil {
                desiredLiveMonitorEnabled = InspectionLiveMonitorPreferenceStore.hasStoredValue
                    ? InspectionLiveMonitorPreferenceStore.isEnabled
                    : LiveMonitorTunnelState.isActive(for: status)
            }
            lastErrorMessage = nil
            logger.verbose("Refresh complete. status=\(manager.connection.status.inspectionDescription) configured=\(manager.isEnabled)")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.critical("Refresh failed: \(error.localizedDescription)")
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
            logger.verbose("Install profile complete. status=\(manager.connection.status.inspectionDescription) configured=\(manager.isEnabled)")
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.critical("Install profile failed: \(error.localizedDescription)")
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
                logger.verbose("Enable flow finished. status=\(manager.connection.status.inspectionDescription) configured=\(manager.isEnabled)")
            } catch {
                lastErrorMessage = error.localizedDescription
                logger.critical("Enable flow failed: \(error.localizedDescription)")
                throw error
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
            logger.verbose("Disable flow finished. status=\(status.inspectionDescription)")
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

    private func updateState(
        from manager: NETunnelProviderManager,
        preservesActiveStatus: Bool = false
    ) {
        let refreshedStatus = manager.connection.status
        let effectiveStatus: NEVPNStatus

        if preservesActiveStatus,
           LiveMonitorTunnelState.isActive(for: status),
           LiveMonitorTunnelState.isActive(for: refreshedStatus) == false {
            effectiveStatus = status
        } else {
            effectiveStatus = refreshedStatus
        }

        status = effectiveStatus
        isConfigured = manager.isEnabled && manager.protocolConfiguration != nil
        InspectionLiveMonitorPreferenceStore.setEnabled(
            LiveMonitorTunnelState.isActive(for: effectiveStatus)
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
                guard let self else {
                    return
                }

                Task { @MainActor [weak self] in
                    await self?.handleStatusChange(for: manager)
                }
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

    private func handleStatusChange(for manager: NETunnelProviderManager) async {
        updateState(from: manager)

        do {
            try await reconcileDesiredStateIfNeeded(using: manager)
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.critical("Status reconciliation failed: \(error.localizedDescription)")
        }
    }
}
