import AppKit
import InspectKit
import SwiftUI

@MainActor
final class InspectMacWindowController {
    private weak var window: NSWindow?

    private let standardMinimumSize = NSSize(width: 960, height: 740)
    private let standardTargetSize = NSSize(width: 1000, height: 760)

    func attach(_ window: NSWindow) {
        self.window = window
        window.contentMinSize = standardMinimumSize
        installDockIcon()
    }

    func ensureStandardSize(animated: Bool = true) {
        guard let window else {
            return
        }

        window.contentMinSize = standardMinimumSize

        var frame = window.frame
        let targetWidth = frame.width > standardTargetSize.width
            ? standardTargetSize.width
            : max(frame.width, standardMinimumSize.width)
        let targetHeight = frame.height > standardTargetSize.height
            ? standardTargetSize.height
            : max(frame.height, standardMinimumSize.height)

        guard frame.width != targetWidth || frame.height != targetHeight else {
            return
        }

        let heightDelta = targetHeight - frame.height
        frame.size.width = targetWidth
        frame.size.height = targetHeight
        frame.origin.y -= heightDelta

        guard animated else {
            window.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1.0)
            window.animator().setFrame(frame, display: true)
        }
    }

    func reveal() {
        guard let window else {
            return
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
    }

    private func installDockIcon() {
        guard let iconURL = Bundle.main.url(forResource: "Inspect", withExtension: "icns"),
              let iconImage = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = iconImage
    }
}

struct InspectMacWindowReader: NSViewRepresentable {
    let onResolve: @MainActor (NSWindow) -> Void

    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
