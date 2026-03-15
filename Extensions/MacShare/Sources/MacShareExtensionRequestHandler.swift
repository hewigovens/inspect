import AppKit
import InspectCore

@MainActor
final class MacShareExtensionRequestHandler {
    let logger = InspectRuntimeLogger(
        category: "ShareExtension",
        scope: "MacShareExtension"
    )

    func handleShareRequest(for extensionContext: NSExtensionContext?) async {
        guard let extensionContext else {
            logger.critical("share request aborted because extensionContext was nil")
            return
        }

        do {
            guard let input = await MacShareExtensionInputLoader.loadInput(
                from: extensionContext,
                logger: logger
            ) else {
                logger.critical("share request had no usable URL or text input")
                extensionContext.cancelRequest(
                    withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
                )
                return
            }

            logger.critical("share request extracted input: \(input)")
            let report = try await TLSInspector().inspect(input: input)
            logger.critical("share request completed TLS inspection for \(report.requestedURL.absoluteString)")
            let token = try InspectionSharedReportStore.save(report)
            logger.critical("share request saved inspection report into app group with token \(token)")
            InspectionSharedPendingReportStore.save(token: token)
            logger.critical("share request queued pending report token for parent app")
            let didActivate = await activateParentApp()
            logger.critical("share request asked macOS to activate parent app: \(didActivate)")
            extensionContext.completeRequest(returningItems: nil)
        } catch {
            logger.critical("share request failed: \(error.localizedDescription)")
            extensionContext.cancelRequest(withError: error)
        }
    }

    private func activateParentApp() async -> Bool {
        guard let appURL = parentApplicationURL() else {
            logger.critical("share request could not resolve parent app URL")
            return false
        }

        let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier
        if let bundleIdentifier,
           let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            logger.critical("share request found running app at \(appURL.path)")
            return runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        logger.critical("share request launching parent app at \(appURL.path)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error {
                    self.logger.critical("share request failed to launch parent app: \(error.localizedDescription)")
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
