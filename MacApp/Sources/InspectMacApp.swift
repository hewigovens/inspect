import InspectFeature
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
            case let .screenshot(scenario):
                InspectMacScreenshotSceneView(scenario: scenario)
            case let .tunnelSmokeTest(configuration):
                InspectMacTunnelSmokeTestView(configuration: configuration)
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
        switch InspectMacLaunchMode.current {
        case .screenshot:
            1440
        case .standard, .tunnelSmokeTest:
            1100
        }
    }

    private var defaultWindowHeight: CGFloat {
        switch InspectMacLaunchMode.current {
        case .screenshot:
            900
        case .standard, .tunnelSmokeTest:
            760
        }
    }
}

private struct InspectMacScreenshotSceneView: View {
    let scenario: InspectionScreenshotScenario

    var body: some View {
        InspectionAppStoreScreenshotView(scenario: scenario)
            .task {
                do {
                    if try InspectMacScreenshotExporter.exportIfNeeded(scenario: scenario) {
                        NSApp.terminate(nil)
                    }
                } catch {
                    fputs("Failed to export screenshot for \(scenario.rawValue): \(error)\n", stderr)
                    NSApp.terminate(nil)
                }
            }
    }
}
