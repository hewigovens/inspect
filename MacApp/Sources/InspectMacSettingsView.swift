import InspectCore
import Observation
import SwiftUI

struct InspectMacSettingsView: View {
    @Bindable var manager: InspectMacLiveMonitorManager
    @Environment(\.openURL) private var openURL
    @State private var verboseTunnelLogsEnabled = InspectLogConfiguration.current().includesVerboseMessages

    var body: some View {
        NavigationStack {
            Form {
                InspectMacLiveMonitorSettingsSection(manager: manager)
                InspectMacDiagnosticsSettingsSection(
                    verboseTunnelLogsBinding: verboseTunnelLogsBinding
                )
                InspectMacAboutSettingsSection(
                    appVersionText: appVersionText,
                    openURL: openURL,
                    aboutURL: aboutURL,
                    appStoreURL: appStoreURL
                )
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .onAppear {
                verboseTunnelLogsEnabled = InspectLogConfiguration.current().includesVerboseMessages
            }
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
