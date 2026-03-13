import AppKit

@MainActor
final class InspectMacAppDelegate: NSObject, NSApplicationDelegate {
    private let shareService = InspectMacShareService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let application = NSApplication.shared
        application.servicesProvider = shareService
        NSUpdateDynamicServices()
    }
}
