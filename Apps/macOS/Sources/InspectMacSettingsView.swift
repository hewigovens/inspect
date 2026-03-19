import InspectCore
import InspectKit
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
                InspectDiagnosticsSettingsSection(
                    verboseTunnelLogsBinding: verboseTunnelLogsBinding
                )
                InspectAboutSettingsSection(openURL: openURL)
            }
            .formStyle(.grouped)
            .navigationTitle(InspectionSettingsStrings.navigationTitle)
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
