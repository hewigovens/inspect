import AppKit
import InspectFeature
import SwiftUI

enum InspectMacScreenshotExporter {
    static let outputPathEnvironmentKey = "INSPECT_MAC_SCREENSHOT_OUTPUT_PATH"
    static let stdoutEnvironmentKey = "INSPECT_MAC_SCREENSHOT_STDOUT"
    static let screenshotSize = CGSize(width: 1440, height: 900)

    static var outputURL: URL? {
        guard let rawValue = ProcessInfo.processInfo.environment[outputPathEnvironmentKey],
              rawValue.isEmpty == false else {
            return nil
        }

        let requestedURL = URL(fileURLWithPath: rawValue)
        let requestedPath = requestedURL.path
        if requestedPath.hasPrefix("/tmp/") || requestedPath.hasPrefix("/private/tmp/") {
            return requestedURL
        }
        return FileManager.default.temporaryDirectory.appending(path: requestedURL.lastPathComponent)
    }

    @MainActor
    static func exportIfNeeded(scenario: InspectionScreenshotScenario) throws -> Bool {
        let writesToStdout = ProcessInfo.processInfo.environment[stdoutEnvironmentKey] == "1"
        guard writesToStdout || outputURL != nil else {
            return false
        }
        if let outputURL {
            fputs("Exporting \(scenario.rawValue) screenshot to \(outputURL.path)\n", stderr)
        } else {
            fputs("Exporting \(scenario.rawValue) screenshot to stdout\n", stderr)
        }

        let content = InspectionAppStoreScreenshotView(scenario: scenario)
            .frame(width: screenshotSize.width, height: screenshotSize.height)
            .background(Color(NSColor.windowBackgroundColor))
            .environment(\.colorScheme, .light)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = CGRect(origin: .zero, size: screenshotSize)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: screenshotSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.backgroundColor = .windowBackgroundColor
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw ScreenshotExportError.renderFailed
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        if let outputURL {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotExportError.writeFailed
        }

        if writesToStdout {
            let base64Data = data.base64EncodedString()
            print("SCREENSHOT_BASE64 \(base64Data)")
        } else if let outputURL {
            try data.write(to: outputURL, options: .atomic)
            fputs("Exported screenshot to \(outputURL.path)\n", stderr)
        }

        return true
    }

    enum ScreenshotExportError: Error {
        case renderFailed
        case writeFailed
    }
}
