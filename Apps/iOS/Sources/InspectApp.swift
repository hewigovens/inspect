import InspectCore
import InspectKit
import SwiftUI

@main
struct InspectApp: App {
    var body: some Scene {
        WindowGroup {
            InspectAppRootView()
                .onOpenURL { url in
                    _ = InspectionExternalInputCenter.handleDeepLink(url)
                }
        }
    }
}
