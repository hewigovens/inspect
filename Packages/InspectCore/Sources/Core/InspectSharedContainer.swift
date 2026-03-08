import Foundation
import OSLog

public enum InspectSharedContainer {
    private static let infoDictionaryKey = "InspectAppGroupIdentifier"
    private static let defaultAppGroupIdentifier = "group.in.fourplex.inspect.monitor"
    private static let bootstrapLogger = Logger(
        subsystem: "in.fourplex.Inspect",
        category: "InspectSharedContainer"
    )

    public static let appGroupIdentifier: String = {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "nil"

        if let value = ProcessInfo.processInfo.environment["INSPECT_APP_GROUP_IDENTIFIER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           value.isEmpty == false {
            bootstrapLogger.debug("Using app group from environment: \(value, privacy: .public)")
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                bootstrapLogger.debug(
                    "Using app group from Info.plist: \(trimmed, privacy: .public) bundle=\(bundleIdentifier, privacy: .public)"
                )
                return trimmed
            }
        }

        bootstrapLogger.debug(
            "Falling back to default app group: \(defaultAppGroupIdentifier, privacy: .public) bundle=\(bundleIdentifier, privacy: .public)"
        )
        return defaultAppGroupIdentifier
    }()

    public static func containerURL(appGroupIdentifier: String = appGroupIdentifier) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
}
