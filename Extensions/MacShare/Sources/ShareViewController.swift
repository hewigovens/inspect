import AppKit
import InspectCore

final class ShareViewController: NSViewController {
    private let handler = MacShareExtensionRequestHandler()
    private var progressIndicator: NSProgressIndicator?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 80))

        let label = NSTextField(labelWithString: "Inspecting certificate…")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        self.progressIndicator = spinner

        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20)
        ])

        view = container

        Task { @MainActor in
            await handler.handleShareRequest(for: extensionContext)
        }
    }
}
