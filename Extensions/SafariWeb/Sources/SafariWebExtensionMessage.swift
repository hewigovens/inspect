import Foundation
import SafariServices

enum SafariWebExtensionMessage {
    static var userInfoKey: String {
        if #available(iOS 15.0, macOS 11.0, *) {
            SFExtensionMessageKey
        } else {
            "message"
        }
    }
}
