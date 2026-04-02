import Foundation
import OSLog

public enum InspectLogVerbosity: String, Codable, CaseIterable, Sendable {
    case criticalOnly
    case verbose

    public var includesVerboseMessages: Bool {
        self == .verbose
    }
}

public enum InspectLogSeverity: String, Sendable {
    case critical = "CRITICAL"
    case verbose = "DEBUG"
}

public enum InspectLogConfiguration {
    public static let defaultsKey = "inspect.log.verbosity.v1"

    public static func current(
        suiteName: String = InspectSharedContainer.appGroupIdentifier
    ) -> InspectLogVerbosity {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        guard let rawValue = defaults.string(forKey: defaultsKey),
              let verbosity = InspectLogVerbosity(rawValue: rawValue)
        else {
            return .criticalOnly
        }

        return verbosity
    }

    public static func set(
        _ verbosity: InspectLogVerbosity,
        suiteName: String = InspectSharedContainer.appGroupIdentifier
    ) {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.set(verbosity.rawValue, forKey: defaultsKey)
    }
}

public struct InspectRuntimeLogger: Sendable {
    private let logger: Logger
    private let scope: String

    public init(
        subsystem: String = "in.fourplex.Inspect",
        category: String,
        scope: String
    ) {
        logger = Logger(subsystem: subsystem, category: category)
        self.scope = scope
    }

    public func critical(_ message: @autoclosure () -> String) {
        emit(message(), severity: .critical)
    }

    public func verbose(_ message: @autoclosure () -> String) {
        guard InspectLogConfiguration.current().includesVerboseMessages else {
            return
        }

        emit(message(), severity: .verbose)
    }

    private func emit(_ message: String, severity: InspectLogSeverity) {
        switch severity {
        case .critical:
            logger.error("\(message, privacy: .public)")
        case .verbose:
            logger.debug("\(message, privacy: .public)")
        }

        InspectSharedLog.append(scope: scope, severity: severity, message: message)
    }
}
