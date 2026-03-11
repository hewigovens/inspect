import SwiftUI

@main
struct InspectMacApp: App {
    var body: some Scene {
        WindowGroup {
            switch InspectMacLaunchMode.current {
            case .standard:
                InspectMacVerificationRootView()
            case let .tunnelSmokeTest(configuration):
                InspectMacTunnelSmokeTestView(configuration: configuration)
            }
        }
    }
}
