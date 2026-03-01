import InspectFeature
import SwiftUI

@main
struct InspectApp: App {
    var body: some Scene {
        WindowGroup {
            InspectionRootView()
                .tint(.inspectAccent)
        }
    }
}
