import InspectCore
import InspectFeature
import SwiftUI

@main
struct InspectMacApp: App {
    @NSApplicationDelegateAdaptor(InspectMacAppDelegate.self) private var appDelegate
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
                guard let deepLink = InspectDeepLink(url: url) else {
                    return
                }

                switch deepLink {
                case let .certificateDetail(token):
                    guard let report = InspectionSharedReportStore.consume(token: token) else {
                        return
                    }

                    appModel.startNewInspection()
                    InspectionExternalInputCenter.submitReport(report, opensCertificateDetail: true)
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
        1100
    }

    private var defaultWindowHeight: CGFloat {
        760
    }
}
