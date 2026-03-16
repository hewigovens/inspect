import Foundation
import InspectCore

public enum InspectionLiveMonitorPreferenceStore {
    private static let enabledKey = "inspect.monitor.enabled.v1"
    nonisolated(unsafe) private static let sharedDefaults = UserDefaults(suiteName: InspectSharedContainer.appGroupIdentifier) ?? .standard

    public static var isEnabled: Bool {
        defaults.bool(forKey: enabledKey)
    }

    public static func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: enabledKey)
    }

    public static func userDefaults() -> UserDefaults {
        defaults
    }

    private static var defaults: UserDefaults {
        sharedDefaults
    }
}
