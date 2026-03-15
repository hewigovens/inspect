import AppKit
import InspectCore

final class ShareViewController: NSViewController {
    private let handler = MacShareExtensionRequestHandler()

    override func loadView() {
        view = NSView(frame: .zero)
        handler.logger.critical("macOS share extension invoked")

        Task { @MainActor in
            await handler.handleShareRequest(for: extensionContext)
        }
    }
}
