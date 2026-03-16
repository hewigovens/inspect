import Foundation

final class SafariWebExtensionResponseContext: @unchecked Sendable {
    let context: NSExtensionContext
    let response: NSExtensionItem

    init(context: NSExtensionContext, response: NSExtensionItem) {
        self.context = context
        self.response = response
    }
}
