import Foundation
import InspectKit

@MainActor
enum InspectAppRouteCenter {
    static let notification = Notification.Name("inspect.ios.app-route")

    private static var pendingRoute: InspectAppRoute?

    static func submit(_ route: InspectAppRoute) {
        pendingRoute = route
        NotificationCenter.default.post(name: notification, object: nil)
    }

    static func consumePendingRoute() -> InspectAppRoute? {
        defer {
            pendingRoute = nil
        }

        return pendingRoute
    }
}
