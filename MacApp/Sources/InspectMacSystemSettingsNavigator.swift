import AppKit
import Foundation

@MainActor
enum InspectMacSystemSettingsNavigator {
    static func openVPNSettings(completion: @escaping @MainActor (Error?) -> Void) {
        let systemSettingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        let configuration = NSWorkspace.OpenConfiguration()

        NSWorkspace.shared.openApplication(at: systemSettingsURL, configuration: configuration) { _, error in
            Task { @MainActor in
                completion(error)
            }
        }
    }
}
