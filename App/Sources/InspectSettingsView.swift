import NetworkExtension
import Observation
import SwiftUI

struct InspectSettingsView: View {
    @Bindable var manager: AppProxyManager

    var body: some View {
        NavigationStack {
            List {
                Section("Live Monitor Tunnel") {
                    settingsValueRow(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Connection",
                        value: statusTitle(manager.status)
                    )
                    settingsValueRow(
                        icon: "checkmark.shield",
                        title: "Configured",
                        value: manager.isConfigured ? "Yes" : "No"
                    )

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

                Section("About") {
                    settingsValueRow(
                        icon: "number.circle",
                        title: "Version",
                        value: appVersionText
                    )

                    settingsLinkRow(
                        icon: "info.circle",
                        title: "About Inspect",
                        destination: aboutURL
                    )

                    settingsLinkRow(
                        icon: "star.circle",
                        title: "Rate on App Store",
                        destination: appStoreURL
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private func settingsValueRow(icon: String, title: String, value: String) -> some View {
        settingsRow(icon: icon, title: title) {
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func settingsLinkRow(icon: String, title: String, destination: URL) -> some View {
        Link(destination: destination) {
            settingsRow(icon: icon, title: title) {
                Text("->")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func settingsRow<Trailing: View>(icon: String, title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.inspectAccent)
                .frame(width: 20, height: 20)

            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            trailing()
        }
    }
}
