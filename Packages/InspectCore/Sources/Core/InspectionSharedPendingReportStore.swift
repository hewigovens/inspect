import Foundation

public enum InspectionSharedPendingReportStore {
    private static let defaultsKey = "inspect.shared.pending-report-token.v1"

    public static func save(token: String) {
        let defaults = UserDefaults(suiteName: InspectSharedContainer.appGroupIdentifier) ?? .standard
        defaults.set(token, forKey: defaultsKey)
    }

    public static func consumeToken() -> String? {
        let defaults = UserDefaults(suiteName: InspectSharedContainer.appGroupIdentifier) ?? .standard
        defer {
            defaults.removeObject(forKey: defaultsKey)
        }

        guard let token = defaults.string(forKey: defaultsKey),
              token.isEmpty == false
        else {
            return nil
        }

        return token
    }
}
