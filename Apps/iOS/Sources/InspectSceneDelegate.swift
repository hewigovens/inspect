import UIKit

final class InspectSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem,
              let route = InspectQuickAction.route(for: shortcutItem) else {
            return
        }

        InspectAppRouteCenter.submit(route)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let route = InspectQuickAction.route(for: shortcutItem) else {
            completionHandler(false)
            return
        }

        InspectAppRouteCenter.submit(route)
        completionHandler(true)
    }
}
