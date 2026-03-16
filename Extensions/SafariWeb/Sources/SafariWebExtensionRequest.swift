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
