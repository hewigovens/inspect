import Foundation

public enum InspectionWindowLayoutPreference: String {
    case standard
    case certificateDetail
}

public enum InspectionWindowLayoutCenter {
    public static let notification = Notification.Name("inspect.feature.window-layout")

    public static func post(_ preference: InspectionWindowLayoutPreference) {
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: ["preference": preference.rawValue]
        )
    }

    public static func preference(from notification: Notification) -> InspectionWindowLayoutPreference? {
        guard let rawValue = notification.userInfo?["preference"] as? String else {
            return nil
        }

        return InspectionWindowLayoutPreference(rawValue: rawValue)
    }
}
