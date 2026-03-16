import Foundation

enum SafariWebExtensionResponse {
    static func complete(context: NSExtensionContext, payload: [String: Any]) {
        let response = NSExtensionItem()
        response.userInfo = [SafariWebExtensionMessage.userInfoKey: payload]
        let responseContext = SafariWebExtensionResponseContext(context: context, response: response)

        DispatchQueue.main.async {
            responseContext.context.completeRequest(returningItems: [responseContext.response], completionHandler: nil)
        }
    }
}
