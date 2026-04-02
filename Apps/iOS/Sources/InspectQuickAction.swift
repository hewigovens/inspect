import InspectKit
import UIKit

enum InspectQuickAction {
    static let inspectType = "in.fourplex.Inspect.shortcut.inspect"
    static let monitorType = "in.fourplex.Inspect.shortcut.monitor"

    static func route(for shortcutItem: UIApplicationShortcutItem) -> InspectAppRoute? {
        switch shortcutItem.type {
        case inspectType:
            return .section(.inspect)
        case monitorType:
            return .section(.monitor)
        default:
            return nil
        }
    }
}
