import InspectCore
import InspectKit
import SwiftUI

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
    }
}
