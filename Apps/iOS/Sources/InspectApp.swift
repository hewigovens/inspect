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
        // Owned by the app, not a scene: the monitor can outlive the main window,
        // and a scene-scoped handler left the toggle inert in that case.
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
