import InspectCore
import InspectFeature
@preconcurrency import NetworkExtension
import Observation
import SwiftUI

struct InspectMacSettingsView: View {
    @Bindable var manager: InspectMacLiveMonitorManager
    @Environment(\.openURL) private var openURL
    @State private var verboseTunnelLogsEnabled = InspectLogConfiguration.current().includesVerboseMessages

    var body: some View {
        NavigationStack {
            Form {
                liveMonitorSection
                diagnosticsSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .onAppear {
                verboseTunnelLogsEnabled = InspectLogConfiguration.current().includesVerboseMessages
            }
        }
    }

    private var liveMonitorSection: some View {
        Section {
            LabeledContent {
                Text(statusTitle(manager.status))
                    .font(.body.weight(.medium))
                    .monospacedDigit()
            } label: {
                InspectMacSettingsRowLabel(
                    title: "Connection",
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: .inspectAccent
                )
            }

            LabeledContent {
                Text(manager.isConfigured ? "Yes" : "No")
                    .font(.body.weight(.medium))
            } label: {
                InspectMacSettingsRowLabel(
                    title: "Configured",
                    systemImage: "checkmark.shield",
                    tint: .green
                )
            }

            LabeledContent {
                Text(InspectMacTunnelDefaults.providerBundleIdentifier)
                    .textSelection(.enabled)
            } label: {
                InspectMacSettingsRowLabel(
                    title: "Provider",
                    systemImage: "shippingbox",
                    tint: .indigo
                )
            }

            if let actionMessage = manager.actionMessage {
                Label(actionMessage, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }

            if let lastErrorMessage = manager.lastErrorMessage {
                Label(lastErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Live Monitor")
        } footer: {
            Text("Use System Settings to manage the Packet Tunnel profile on this Mac.")
        }
    }

    private var diagnosticsSection: some View {
        Section {
            NavigationLink {
                InspectionEventsView()
            } label: {
                InspectMacSettingsNavigationRowLabel(
                    title: "Events",
                    systemImage: "waveform.path.ecg",
                    tint: .orange
                )
            }

            NavigationLink {
                InspectionTunnelLogView()
            } label: {
                InspectMacSettingsNavigationRowLabel(
                    title: "Tunnel Log",
                    systemImage: "doc.text.magnifyingglass",
                    tint: .orange
                )
            }

            Toggle(isOn: verboseTunnelLogsBinding) {
                InspectMacSettingsRowLabel(
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

    private var aboutSection: some View {
        Section("About") {
            LabeledContent {
                Text(appVersionText)
                    .font(.body.weight(.medium))
            } label: {
                InspectMacSettingsRowLabel(
                    title: "Version",
                    systemImage: "app.badge",
                    tint: .blue
                )
            }

            Button {
                openURL(aboutURL)
            } label: {
                InspectMacSettingsButtonRowLabel(
                    title: "About Inspect",
                    systemImage: "info.circle",
                    tint: .indigo
                )
            }
            .buttonStyle(.plain)

            Button {
                openURL(appStoreURL)
            } label: {
                InspectMacSettingsButtonRowLabel(
                    title: "Rate on App Store",
                    systemImage: "star.circle",
                    tint: .yellow
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func statusTitle(_ status: NEVPNStatus) -> String {
        switch status {
        case .invalid:
            return "Invalid"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reasserting"
        case .disconnecting:
            return "Disconnecting"
        @unknown default:
            return "Unknown"
        }
    }

    private var verboseTunnelLogsBinding: Binding<Bool> {
        Binding(
            get: { verboseTunnelLogsEnabled },
            set: { newValue in
                verboseTunnelLogsEnabled = newValue
                InspectLogConfiguration.set(newValue ? .verbose : .criticalOnly)
            }
        )
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var aboutURL: URL {
        URL(string: "https://fourplexlabs.github.io/Inspect/about.html")!
    }

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/us/app/inspect-view-tls-certificate/id1074957486")!
    }
}

private struct InspectMacSettingsRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.15))

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            Text(title)
        }
    }
}

private struct InspectMacSettingsButtonRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack {
            InspectMacSettingsRowLabel(
                title: title,
                systemImage: systemImage,
                tint: tint
            )

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct InspectMacSettingsNavigationRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        InspectMacSettingsRowLabel(
            title: title,
            systemImage: systemImage,
            tint: tint
        )
    }
}
