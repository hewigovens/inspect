import Foundation
@preconcurrency import NetworkExtension

extension InspectMacVerificationManager {
    func refresh() async {
        diagnostics.ensureVerboseLoggingEnabled()
        appendDiagnostic("Refreshing tunnel manager state")
        do {
            let manager = try await tunnelService.loadOrCreateManager()
            self.manager = manager
            configureObservers(for: manager)
            updateState(from: manager)
            actionMessage = "Status refreshed."
            lastErrorMessage = nil
            appendDiagnostic("Refresh complete. \(tunnelService.describe(manager))")
        } catch {
            lastErrorMessage = error.localizedDescription
            appendErrorDiagnostics(prefix: "Refresh failed", error: error)
        }
    }

    func installProfile() async {
        diagnostics.ensureVerboseLoggingEnabled()
        appendDiagnostic("Installing or updating VPN profile")
        do {
            let manager = try await tunnelService.loadOrCreateManager()
            let needsConfiguration = InspectMacTunnelPreferences.needsConfiguration(
                manager,
                localizedDescription: tunnelService.profile.localizedDescription,
                providerBundleIdentifier: tunnelService.profile.providerBundleIdentifier
            )
            try await tunnelService.configureIfNeeded(manager)
            if needsConfiguration {
                appendDiagnostic("Saved VPN profile to preferences")
                appendDiagnostic("Reloaded VPN profile from preferences")
            } else {
                appendDiagnostic("VPN profile already matched the expected configuration")
            }

            self.manager = manager
            configureObservers(for: manager)
            updateState(from: manager)
            actionMessage = "VPN profile saved. Open System Settings > VPN and look for Inspect."
            lastErrorMessage = nil
            appendDiagnostic("VPN profile is ready. \(tunnelService.describe(manager))")
        } catch {
            lastErrorMessage = error.localizedDescription
            appendErrorDiagnostics(prefix: "Install profile failed", error: error)
        }
    }
}
