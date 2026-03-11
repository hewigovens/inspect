import SwiftUI

@main
struct InspectMacApp: App {
    @State private var appModel = InspectMacAppModel()
    @State private var liveMonitorManager = InspectMacLiveMonitorManager()
    @State private var windowController = InspectMacWindowController()

    var body: some Scene {
        WindowGroup {
            switch InspectMacLaunchMode.current {
            case .standard:
                InspectMacRootView(
                    appModel: appModel,
                    manager: liveMonitorManager,
                    windowController: windowController
                )
            case let .tunnelSmokeTest(configuration):
                InspectMacTunnelSmokeTestView(configuration: configuration)
            }
        }
        .defaultSize(width: 1100, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Inspection") {
                    appModel.startNewInspection()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            InspectMacSettingsView(manager: liveMonitorManager)
                .frame(minWidth: 520, minHeight: 460)
        }
    }
}
