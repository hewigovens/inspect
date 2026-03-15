import AppKit
import InspectKit
import QuartzCore
import SwiftUI

@MainActor
final class InspectMacWindowController {
    private weak var window: NSWindow?
    private var currentPreference: InspectionWindowLayoutPreference = .standard

    private let standardMinimumSize = NSSize(width: 960, height: 740)
    private let standardTargetSize = NSSize(width: 1000, height: 760)
    private let detailMinimumSize = NSSize(width: 1140, height: 770)
    private let detailTargetSize = NSSize(width: 1200, height: 790)

    func attach(_ window: NSWindow) {
        self.window = window
        window.contentMinSize = standardMinimumSize
        currentPreference = .standard
        installDockIcon()
    }

    func transition(to preference: InspectionWindowLayoutPreference, animated: Bool = true) {
        guard let window else {
            return
        }

        let targetMinimumSize: NSSize
        let targetSize: NSSize
        switch preference {
        case .standard:
            targetMinimumSize = standardMinimumSize
            targetSize = standardTargetSize
        case .certificateDetail:
            targetMinimumSize = detailMinimumSize
            targetSize = detailTargetSize
        }

        let previousPreference = currentPreference
        currentPreference = preference
        window.contentMinSize = targetMinimumSize

        var frame = window.frame
        let targetWidth: CGFloat
        let targetHeight: CGFloat

        switch preference {
        case .standard:
            targetWidth = frame.width > targetSize.width ? targetSize.width : max(frame.width, targetMinimumSize.width)
            targetHeight = frame.height > targetSize.height ? targetSize.height : max(frame.height, targetMinimumSize.height)
        case .certificateDetail:
            targetWidth = max(frame.width, targetSize.width)
            targetHeight = max(frame.height, targetSize.height)
        }

        guard previousPreference != preference || frame.width != targetWidth || frame.height != targetHeight else {
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
              let iconImage = NSImage(contentsOf: iconURL) else {
            return
        }

        NSApp.applicationIconImage = iconImage
    }
}

struct InspectMacWindowReader: NSViewRepresentable {
    let onResolve: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
