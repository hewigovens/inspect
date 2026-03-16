import Foundation
import InspectKit
@preconcurrency import NetworkExtension

extension InspectMacVerificationManager {
    func updateState(from manager: NETunnelProviderManager) {
        let currentStatus = manager.connection.status
        status = currentStatus
        isConfigured = manager.isEnabled && manager.protocolConfiguration != nil
        appendDiagnostic("Updated state. status=\(currentStatus.inspectionDescription) configured=\(isConfigured)")
    }

    func configureObservers(for manager: NETunnelProviderManager) {
        observationBridge.observe(
            manager: manager,
            onStatusChange: { [weak self] in
                guard let self else {
                    return
                }

                self.appendDiagnostic("Observed VPN status change -> \(manager.connection.status.inspectionDescription)")
                self.updateState(from: manager)
            },
            onConfigurationChange: { [weak self] in
                guard let self else {
                    return
                }

                Task {
                    await self.logConfigurationChange()
                    await self.refresh()
                }
            }
        )
    }

    func logConfigurationChange() async {
        appendDiagnostic("Observed VPN configuration change notification")
    }

    func appendDiagnostic(_ message: String) {
        diagnostics.info(message)
    }

    func appendErrorDiagnostics(prefix: String, error: Error) {
        diagnostics.error(prefix: prefix, error: error)
    }
}
