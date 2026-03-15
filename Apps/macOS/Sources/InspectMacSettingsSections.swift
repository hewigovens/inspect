import InspectCore
import InspectKit
import SwiftUI

struct InspectMacLiveMonitorSettingsSection: View {
    @Bindable var manager: InspectMacLiveMonitorManager

    var body: some View {
        Section {
            InspectMacSettingsValueRow(
                title: "Connection",
                systemImage: "dot.radiowaves.left.and.right",
                tint: .inspectAccent
            ) {
                Text(manager.status.description)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
            }

            InspectMacSettingsValueRow(
                title: "Configured",
                systemImage: "checkmark.shield",
                tint: .green
            ) {
                Text(manager.isConfigured ? "Yes" : "No")
                    .font(.body.weight(.medium))
            }

            InspectMacSettingsValueRow(
                title: "Provider",
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
            Text("Live Monitor")
        } footer: {
            Text("Use System Settings to manage the Packet Tunnel profile on this Mac.")
        }
    }
}

struct InspectMacDiagnosticsSettingsSection: View {
    let verboseTunnelLogsBinding: Binding<Bool>

    var body: some View {
        Section {
            InspectMacSettingsNavigationRow(
                title: "Events",
                systemImage: "waveform.path.ecg",
                tint: .orange
            ) {
                InspectionEventsView()
            }

            InspectMacSettingsNavigationRow(
                title: "Tunnel Log",
                systemImage: "doc.text.magnifyingglass",
                tint: .orange
            ) {
                InspectionTunnelLogView()
            }

            Toggle(isOn: verboseTunnelLogsBinding) {
                InspectMacSettingsIconLabel(
                    title: "Verbose Tunnel Logging",
                    systemImage: "ladybug",
                    tint: .pink
                )
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Verbose logging applies on the next Packet Tunnel start.")
        }
    }
}

struct InspectMacAboutSettingsSection: View {
    let appVersionText: String
    let openURL: OpenURLAction

    var body: some View {
        Section("About") {
            InspectMacSettingsValueRow(
                title: "Version",
                systemImage: "app.badge",
                tint: .blue
            ) {
                Text(appVersionText)
                    .font(.body.weight(.medium))
            }

            InspectMacSettingsActionRow(
                title: "About Inspect",
                systemImage: "info.circle",
                tint: .indigo
            ) {
                openURL(InspectAppLinks.about)
            }

            InspectMacSettingsActionRow(
                title: "Rate on App Store",
                systemImage: "star.circle",
                tint: .yellow
            ) {
                openURL(InspectAppLinks.appStore)
            }
        }
    }
}
