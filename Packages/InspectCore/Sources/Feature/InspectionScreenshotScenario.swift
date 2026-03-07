import Foundation

public enum InspectionScreenshotScenario: String {
    case home
    case summary
    case risk
    case detail

    public static var current: InspectionScreenshotScenario? {
        ProcessInfo.processInfo.environment["INSPECT_SCREENSHOT_SCENARIO"]
            .flatMap(InspectionScreenshotScenario.init(rawValue:))
    }

    var initialURL: URL? {
        switch self {
        case .home:
            return nil
        case .summary, .detail:
            return URL(string: "https://hewig.dev")
        case .risk:
            return URL(string: "https://untrusted-root.badssl.com")
        }
    }

    var showsAboutCard: Bool {
        false
    }

    var showsCertificateDetail: Bool {
        self == .detail
    }

    var showsDemoTargets: Bool {
        self == .home
    }

    var showsRecents: Bool {
        false
    }

    var showsMonitorCard: Bool {
        false
    }
}
