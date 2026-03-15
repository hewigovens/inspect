import InspectCore
import Observation
import SwiftUI

struct InspectSettingsView: View {
    @Bindable var manager: LiveMonitorManager
    @Environment(\.openURL) private var openURL
    @State private var verboseTunnelLogsEnabled = InspectLogConfiguration.current().includesVerboseMessages

    var body: some View {
        NavigationStack {
            Form {
                InspectTunnelSettingsSection(manager: manager)
                InspectDiagnosticsSettingsSection(
                    verboseTunnelLogsBinding: verboseTunnelLogsBinding
                )
                InspectAboutSettingsSection(openURL: openURL)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
}
