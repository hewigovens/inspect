import InspectFeature
import NetworkExtension
import Observation
import SwiftUI

struct InspectTunnelSettingsSection: View {
    @Bindable var manager: LiveMonitorManager

    var body: some View {
        Section("Live Monitor Tunnel") {
            InspectSettingsValueRow(
                title: "Connection",
                systemImage: "dot.radiowaves.left.and.right",
                tint: .inspectAccent
            ) {
                Text(manager.status.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            InspectSettingsValueRow(
                title: "Configured",
                systemImage: "checkmark.shield",
                tint: .green
            ) {
                Text(manager.isConfigured ? "Yes" : "No")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            if manager.status == .invalid {
                InspectSettingsMessageRow(
                    message: "Use the Live Monitor switch in the Monitor tab to install and control the profile.",
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
                title: "Events",
                systemImage: "waveform.path.ecg",
                tint: .orange
            ) {
                InspectionEventsView()
            }

            InspectSettingsNavigationRow(
                title: "Tunnel Log",
                systemImage: "doc.text.magnifyingglass",
                tint: .orange
            ) {
                InspectionTunnelLogView()
            }

            Toggle(isOn: verboseTunnelLogsBinding) {
                InspectSettingsIconLabel(
                    title: "Verbose",
                    systemImage: "ladybug",
                    tint: .pink
                )
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Use Events and Tunnel Log for troubleshooting. Verbose logging applies on the next Live Monitor start.")
        }
    }
}

struct InspectAboutSettingsSection: View {
    let openURL: OpenURLAction

    var body: some View {
        Section("About") {
            InspectSettingsValueRow(
                title: "Version",
                systemImage: "app.badge",
                tint: .blue
            ) {
                Text(InspectionAppMetadata.versionBuildText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            InspectSettingsActionRow(
                title: "About Inspect",
                systemImage: "info.circle",
                tint: .indigo
            ) {
                openURL(InspectAppLinks.about)
            }

            InspectSettingsActionRow(
                title: "Rate on App Store",
                systemImage: "star.circle",
                tint: .yellow
            ) {
                openURL(InspectAppLinks.appStore)
            }
        }
    }
}
