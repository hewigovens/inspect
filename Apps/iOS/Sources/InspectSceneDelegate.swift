import UIKit

final class InspectSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem,
              let route = InspectQuickAction.route(for: shortcutItem)
        else {
            return
        }

        InspectAppRouteCenter.submit(route)
    }

    func windowScene(
        _: UIWindowScene,
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
