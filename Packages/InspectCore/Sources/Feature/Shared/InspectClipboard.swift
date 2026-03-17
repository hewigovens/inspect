import SwiftUI

enum InspectClipboard {
    @MainActor
    static func copy(_ value: String) {
        InspectPlatform.copyToPasteboard(value)
    }
}
