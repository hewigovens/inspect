import InspectKit
import NetworkExtension
import Observation
import SwiftUI

struct InspectTunnelSettingsSection: View {
    @Bindable var manager: LiveMonitorManager

    var body: some View {
        Section(InspectionSettingsStrings.IOS.liveMonitorSection) {
            InspectSettingsValueRow(
                title: InspectionSettingsStrings.Shared.configured,
                systemImage: "checkmark.shield",
                tint: .green
            ) {
                Text(manager.isConfigured ? InspectionCommonStrings.yes : InspectionCommonStrings.no)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            if manager.status == .invalid {
                InspectSettingsMessageRow(
                    message: InspectionSettingsStrings.IOS.invalidMonitorMessage,
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
        }
    }
}
