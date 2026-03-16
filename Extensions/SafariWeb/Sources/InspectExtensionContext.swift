import Foundation

final class InspectExtensionContext: @unchecked Sendable {
    let context: NSExtensionContext

    init(_ context: NSExtensionContext) {
        self.context = context
    }
}
