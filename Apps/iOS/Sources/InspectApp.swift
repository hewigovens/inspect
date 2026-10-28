import InspectCore
import InspectKit
import SwiftUI

enum InspectWindowID {
    static let monitor = "monitor"
}

@main
struct InspectApp: App {
    @UIApplicationDelegateAdaptor(InspectAppDelegate.self) private var appDelegate

    init() {
        // App-scoped, not scene-scoped: closing the main window must not clear
        // the handler the monitor-only scene depends on.
        let manager = LiveMonitorManager.shared
        InspectionLiveMonitorCoordinator.configure { isEnabled in
            try await manager.setLiveMonitorEnabled(isEnabled)
        }
    }

    var body: some Scene {
        WindowGroup {
            InspectAppRootView()
                .onOpenURL { url in
                    if let route = InspectAppRoute(url: url) {
                        InspectAppRouteCenter.submit(route)
                    } else {
                        _ = InspectionExternalInputCenter.handleDeepLink(url)
                    }
                }
        }

        WindowGroup(id: InspectWindowID.monitor) {
            InspectMonitorWindowView()
        }
    }
}
