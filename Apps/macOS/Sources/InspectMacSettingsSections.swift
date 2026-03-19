import InspectCore
import InspectKit
import SwiftUI

struct InspectMacLiveMonitorSettingsSection: View {
    @Bindable var manager: InspectMacLiveMonitorManager

    var body: some View {
        Section {
            InspectSettingsValueRow(
                title: InspectionSettingsStrings.Shared.configured,
                systemImage: "checkmark.shield",
                tint: .green
            ) {
                Text(manager.isConfigured ? InspectionCommonStrings.yes : InspectionCommonStrings.no)
                    .font(.body.weight(.medium))
            }

            InspectSettingsValueRow(
                title: InspectionSettingsStrings.Mac.provider,
                systemImage: "shippingbox",
                tint: .indigo
            ) {
                Text(InspectMacTunnelDefaults.providerBundleIdentifier)
                    .textSelection(.enabled)
            }

            if let actionMessage = manager.actionMessage {
                InspectSettingsMessageRow(
                    message: actionMessage,
                    systemImage: "info.circle",
                    hierarchicalStyle: .secondary
                )
            }

            if let lastErrorMessage = manager.lastErrorMessage {
                InspectSettingsMessageRow(
                    message: lastErrorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
        } header: {
            Text(InspectionSettingsStrings.Mac.liveMonitorSection)
        } footer: {
            Text(InspectionSettingsStrings.Mac.liveMonitorFooter)
        }
    }
}
