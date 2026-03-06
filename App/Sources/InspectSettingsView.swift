import InspectFeature
import NetworkExtension
import Observation
import SwiftUI

struct InspectSettingsView: View {
    @Bindable var manager: LiveMonitorManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                tunnelSection
                diagnosticsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var tunnelSection: some View {
        Section("Live Monitor Tunnel") {
            LabeledContent {
                Text(statusTitle(manager.status))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            } label: {
                InspectSettingsRowLabel(
                    title: "Connection",
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: Color.inspectAccent
                )
            }

            LabeledContent {
                Text(manager.isConfigured ? "Yes" : "No")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            } label: {
                InspectSettingsRowLabel(
                    title: "Configured",
                    systemImage: "checkmark.shield",
                    tint: .green
                )
            }

            if manager.status == .invalid {
                Label("Use the Live Monitor switch in the Monitor tab to install and control the profile.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let lastErrorMessage = manager.lastErrorMessage {
                Label(lastErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var diagnosticsSection: some View {
        Section {
            NavigationLink {
                InspectionDiagnosticsView()
            } label: {
                InspectSettingsRowLabel(
                    title: "Events & Tunnel Log",
                    systemImage: "stethoscope",
                    tint: .orange
                )
            }
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Use Diagnostics for raw monitor events, log export, and tunnel troubleshooting.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent {
                Text(appVersionText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            } label: {
                InspectSettingsRowLabel(
                    title: "Version",
                    systemImage: "app.badge",
                    tint: .blue
                )
            }

            Button {
                openURL(aboutURL)
            } label: {
                HStack {
                    InspectSettingsRowLabel(
                        title: "About Inspect",
                        systemImage: "info.circle",
                        tint: .indigo
                    )

                    Spacer()

                    Text("->")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                openURL(appStoreURL)
            } label: {
                HStack {
                    InspectSettingsRowLabel(
                        title: "Rate on App Store",
                        systemImage: "star.circle",
                        tint: .yellow
                    )

                    Spacer()

                    Text("->")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/us/app/inspect-view-tls-certificate/id1074957486")!
    }

    private var aboutURL: URL {
        URL(string: "https://fourplexlabs.github.io/Inspect/about.html")!
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
}

private struct InspectSettingsRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.14))

                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 16, height: 16, alignment: .center)
            }
            .frame(width: 28, height: 28)

            Text(title)
        }
    }
}
