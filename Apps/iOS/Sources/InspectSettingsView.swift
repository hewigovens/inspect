import InspectCore
import InspectKit
import Observation
import SwiftUI

struct InspectSettingsView: View {
    @Bindable var manager: LiveMonitorManager
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var verboseTunnelLogsEnabled = InspectLogConfiguration.current().includesVerboseMessages

    var body: some View {
        NavigationStack {
            Form {
                InspectTunnelSettingsSection(manager: manager)
                InspectDiagnosticsSettingsSection(
                    verboseTunnelLogsBinding: verboseTunnelLogsBinding,
                    footerText: InspectionSettingsStrings.IOS.diagnosticsFooter
                )
                if supportsMultipleWindows {
                    monitorWindowSection
                }
                InspectAboutSettingsSection(openURL: openURL)
            }
            .navigationTitle(InspectionSettingsStrings.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                verboseTunnelLogsEnabled = InspectLogConfiguration.current().includesVerboseMessages
            }
        }
    }

    private var monitorWindowSection: some View {
        Section {
            InspectSettingsActionRow(
                title: InspectionSettingsStrings.IOS.openMonitorWindow,
                systemImage: "macwindow.badge.plus",
                tint: .blue
            ) {
                openWindow(id: InspectWindowID.monitor)
            }
        } footer: {
            Text(InspectionSettingsStrings.IOS.openMonitorWindowFooter)
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
