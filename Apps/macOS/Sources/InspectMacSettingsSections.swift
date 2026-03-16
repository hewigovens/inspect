import InspectCore
import InspectKit
import SwiftUI

struct InspectMacLiveMonitorSettingsSection: View {
    @Bindable var manager: InspectMacLiveMonitorManager

    var body: some View {
        Section {
            InspectMacSettingsValueRow(
                title: InspectionSettingsStrings.Shared.connection,
                systemImage: "dot.radiowaves.left.and.right",
                tint: .inspectAccent
            ) {
                Text(manager.status.inspectionDescription)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
            }

            InspectMacSettingsValueRow(
                title: InspectionSettingsStrings.Shared.configured,
                systemImage: "checkmark.shield",
                tint: .green
            ) {
                Text(manager.isConfigured ? InspectionCommonStrings.yes : InspectionCommonStrings.no)
                    .font(.body.weight(.medium))
            }

            InspectMacSettingsValueRow(
                title: InspectionSettingsStrings.Mac.provider,
                systemImage: "shippingbox",
                tint: .indigo
            ) {
                Text(InspectMacTunnelDefaults.providerBundleIdentifier)
                    .textSelection(.enabled)
            }

            if let actionMessage = manager.actionMessage {
                InspectMacSettingsMessageRow(
                    message: actionMessage,
                    systemImage: "info.circle",
                    hierarchicalStyle: .secondary
                )
            }

            if let lastErrorMessage = manager.lastErrorMessage {
                InspectMacSettingsMessageRow(
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

struct InspectMacDiagnosticsSettingsSection: View {
    let verboseTunnelLogsBinding: Binding<Bool>

    var body: some View {
        Section {
            InspectMacSettingsNavigationRow(
                title: InspectionSettingsStrings.Shared.events,
                systemImage: "waveform.path.ecg",
                tint: .orange
            ) {
                InspectionEventsView()
            }

            InspectMacSettingsNavigationRow(
                title: InspectionSettingsStrings.Shared.tunnelLog,
                systemImage: "doc.text.magnifyingglass",
                tint: .orange
            ) {
                InspectionTunnelLogView()
            }

            Toggle(isOn: verboseTunnelLogsBinding) {
                InspectMacSettingsIconLabel(
                    title: InspectionSettingsStrings.Shared.verbose,
                    systemImage: "ladybug",
                    tint: .pink
                )
            }
        } header: {
            Text(InspectionSettingsStrings.Shared.diagnostics)
        } footer: {
            Text(InspectionSettingsStrings.Shared.verboseFooter)
        }
    }
}

struct InspectMacAboutSettingsSection: View {
    let appVersionText: String
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
                    InspectMacSettingsIconLabel(
                        title: InspectionSettingsStrings.Shared.version,
                        systemImage: "app.badge",
                        tint: .blue
                    )

                    Spacer(minLength: 12)

                    Text(appVersionText)
                        .font(.body.weight(.medium))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            InspectMacSettingsActionRow(
                title: InspectionSettingsStrings.Shared.aboutInspect,
                systemImage: "info.circle",
                tint: .indigo
            ) {
                openURL(InspectAppLinks.about)
            }

            InspectMacSettingsActionRow(
                title: InspectionSettingsStrings.Shared.rateOnAppStore,
                systemImage: "star.circle",
                tint: .yellow
            ) {
                openURL(InspectAppLinks.appStore)
            }
        }
    }
}
