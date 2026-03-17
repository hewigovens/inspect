import AppKit
import InspectCore

final class ShareViewController: NSViewController {
    private let handler = MacShareExtensionRequestHandler()

    override func loadView() {
        view = NSView(frame: .zero)

        Task { @MainActor in
            await handler.handleShareRequest(for: extensionContext)
        }
    }
}
