import InspectKit
import NetworkExtension
import Observation
import SwiftUI

struct InspectTunnelSettingsSection: View {
    @Bindable var manager: LiveMonitorManager

    var body: some View {
        Section(InspectionSettingsStrings.IOS.liveMonitorSection) {
            InspectSettingsValueRow(
                title: InspectionSettingsStrings.Shared.connection,
                systemImage: "dot.radiowaves.left.and.right",
                tint: .inspectAccent
            ) {
                Text(manager.status.inspectionDescription)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

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
                    color: .secondary
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

struct InspectDiagnosticsSettingsSection: View {
    let verboseTunnelLogsBinding: Binding<Bool>

    var body: some View {
        Section {
            InspectSettingsNavigationRow(
                title: InspectionSettingsStrings.Shared.events,
                systemImage: "waveform.path.ecg",
                tint: .orange
            ) {
                InspectionEventsView()
            }

            InspectSettingsNavigationRow(
                title: InspectionSettingsStrings.Shared.tunnelLog,
                systemImage: "doc.text.magnifyingglass",
                tint: .orange
            ) {
                InspectionTunnelLogView()
            }

            Toggle(isOn: verboseTunnelLogsBinding) {
                InspectSettingsIconLabel(
                    title: InspectionSettingsStrings.Shared.verbose,
                    systemImage: "ladybug",
                    tint: .pink
                )
            }
        } header: {
            Text(InspectionSettingsStrings.Shared.diagnostics)
        } footer: {
            Text(InspectionSettingsStrings.IOS.diagnosticsFooter)
        }
    }
}

struct InspectAboutSettingsSection: View {
    let openURL: OpenURLAction
    @State private var reviewDebugTrigger = InspectionReviewDebugTrigger()

    var body: some View {
        Section(InspectionSettingsStrings.Shared.about) {
            Button {
                if reviewDebugTrigger.registerTap() {
                    InspectReviewRequester.requestReview()
                }
            } label: {
                HStack(spacing: 0) {
                    InspectSettingsIconLabel(
                        title: InspectionSettingsStrings.Shared.version,
                        systemImage: "app.badge",
                        tint: .blue
                    )

                    Spacer(minLength: 12)

                    Text(InspectionAppMetadata.versionBuildText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            InspectSettingsActionRow(
                title: InspectionSettingsStrings.Shared.aboutInspect,
                systemImage: "info.circle",
                tint: .indigo
            ) {
                openURL(InspectAppLinks.about)
            }

            InspectSettingsActionRow(
                title: InspectionSettingsStrings.Shared.rateOnAppStore,
                systemImage: "star.circle",
                tint: .yellow
            ) {
                openURL(InspectAppLinks.appStore)
            }
        }
    }
}
