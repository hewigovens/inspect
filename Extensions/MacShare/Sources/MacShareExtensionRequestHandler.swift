import AppKit
import InspectCore

@MainActor
final class MacShareExtensionRequestHandler {
    func handleShareRequest(for extensionContext: NSExtensionContext?) async {
        guard let extensionContext else {
            return
        }

        do {
            guard let input = await ExtensionInputExtractor.loadInputString(from: extensionContext) else {
                extensionContext.cancelRequest(
                    withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
                )
                return
            }

            let inspection = try await TLSInspector().inspect(input: input)
            guard let report = inspection.primaryReport else {
                throw InspectionError.missingServerTrust
            }
            let token = try InspectionSharedReportStore.save(report)
            InspectionSharedPendingReportStore.save(token: token)
            _ = await activateParentApp()
            extensionContext.completeRequest(returningItems: nil)
        } catch {
            extensionContext.cancelRequest(withError: error)
        }
    }

    private func activateParentApp() async -> Bool {
        guard let appURL = parentApplicationURL() else {
            return false
        }

        let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier
        if let bundleIdentifier,
           let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        {
            return runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if error != nil {
                    continuation.resume(returning: false)
                    return
                }

                continuation.resume(returning: true)
            }
        }
    }

    private func parentApplicationURL() -> URL? {
        let extensionBundleURL = Bundle.main.bundleURL
        let contentsURL = extensionBundleURL.deletingLastPathComponent().deletingLastPathComponent()
        let appURL = contentsURL.deletingLastPathComponent()
        guard appURL.pathExtension == "app" else {
            return nil
        }

        return appURL
    }
}
