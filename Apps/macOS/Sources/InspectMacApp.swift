import InspectCore
import InspectFeature
import SwiftUI

@main
struct InspectMacApp: App {
    @State private var appModel = InspectMacAppModel()
    @State private var liveMonitorManager = InspectMacLiveMonitorManager()
    @State private var windowController = InspectMacWindowController()

    var body: some Scene {
        WindowGroup {
            InspectMacRootView(
                appModel: appModel,
                manager: liveMonitorManager,
                windowController: windowController
            )
            .onOpenURL { url in
                _ = InspectionExternalInputCenter.handleDeepLink(url) {
                    appModel.startNewInspection()
                    windowController.reveal()
                }
            }
        }
        .defaultSize(width: defaultWindowWidth, height: defaultWindowHeight)
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

    private var defaultWindowWidth: CGFloat {
        780
    }

    private var defaultWindowHeight: CGFloat {
        660
    }
}
