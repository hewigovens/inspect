import Foundation
import SafariServices

struct SafariWebExtensionRequest {
    let type: String
    let urlString: String?
    let reportToken: String?

    init?(item: NSExtensionItem?) {
        guard let message = item?.userInfo?[SafariWebExtensionMessage.userInfoKey] as? [String: Any],
              let type = message["type"] as? String else {
            return nil
        }

        self.type = type
        urlString = message["url"] as? String
        reportToken = message["reportToken"] as? String
    }
}

enum SafariWebExtensionMessage {
    static var userInfoKey: String {
        if #available(iOS 15.0, macOS 11.0, *) {
            SFExtensionMessageKey
        } else {
            "message"
        }
    }
}

enum SafariWebExtensionResponse {
    static func complete(context: NSExtensionContext, payload: [String: Any]) {
        let response = NSExtensionItem()
        response.userInfo = [SafariWebExtensionMessage.userInfoKey: payload]
        let box = ExtensionCompletionBox(context: context, response: response)

        DispatchQueue.main.async {
            box.context.completeRequest(returningItems: [box.response], completionHandler: nil)
        }
    }
}

private final class ExtensionCompletionBox: @unchecked Sendable {
    let context: NSExtensionContext
    let response: NSExtensionItem

    init(context: NSExtensionContext, response: NSExtensionItem) {
        self.context = context
        self.response = response
    }
}
