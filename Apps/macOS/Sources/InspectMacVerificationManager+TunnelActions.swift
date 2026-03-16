import Foundation
import InspectKit
@preconcurrency import NetworkExtension

extension InspectMacVerificationManager {
    func startTunnel() async {
        diagnostics.ensureVerboseLoggingEnabled()
        appendDiagnostic("Start tunnel requested")
        do {
            let manager = try await preparedManager()
            try await manager.loadFromPreferences()
            appendDiagnostic("Reloaded manager before start. \(tunnelService.describe(manager))")
            try manager.connection.startVPNTunnel()
            updateState(from: manager)
            actionMessage = "Tunnel start requested."
            lastErrorMessage = nil
            appendDiagnostic("startVPNTunnel() returned successfully. status=\(manager.connection.status.inspectionDescription)")
        } catch {
            lastErrorMessage = error.localizedDescription
            appendErrorDiagnostics(prefix: "Start tunnel failed", error: error)
        }
    }

    func stopTunnel() async {
        guard let manager = manager else {
            actionMessage = "No active tunnel manager is loaded yet."
            appendDiagnostic("Stop tunnel skipped because no manager is loaded")
            return
        }

        appendDiagnostic("Stop tunnel requested. currentStatus=\(manager.connection.status.inspectionDescription)")
        manager.connection.stopVPNTunnel()
        updateState(from: manager)
        actionMessage = "Tunnel stop requested."
        lastErrorMessage = nil
        appendDiagnostic("stopVPNTunnel() sent. status=\(manager.connection.status.inspectionDescription)")
    }

    func openSystemSettings() {
        actionMessage = "Navigate to System Settings > VPN."
        appendDiagnostic("Opening System Settings")

        InspectMacSystemSettingsNavigator.openVPNSettings { [weak self] error in
            guard let self else {
                return
            }

            if let error {
                self.lastErrorMessage = error.localizedDescription
                self.appendErrorDiagnostics(prefix: "Open System Settings failed", error: error)
            } else {
                self.appendDiagnostic("System Settings opened")
            }
        }
    }

    func preparedManager() async throws -> NETunnelProviderManager {
        if let manager {
            appendDiagnostic("Using cached manager. \(tunnelService.describe(manager))")
            return manager
        }

        let manager = try await tunnelService.loadOrCreateManager()
        self.manager = manager
        configureObservers(for: manager)
        updateState(from: manager)
        appendDiagnostic("Prepared fresh manager. \(tunnelService.describe(manager))")
        return manager
    }
}
