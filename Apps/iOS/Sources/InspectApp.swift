import InspectCore
import InspectKit
import SwiftUI

enum InspectWindowID {
    static let monitor = "monitor"
}

@main
struct InspectApp: App {
    @UIApplicationDelegateAdaptor(InspectAppDelegate.self) private var appDelegate

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
