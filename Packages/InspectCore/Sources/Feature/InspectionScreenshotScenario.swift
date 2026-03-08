import Foundation

public enum InspectionScreenshotScenario: String {
    case inspectTab = "inspect-tab"
    case monitorTab = "monitor-tab"
    case hostDetail = "host-detail"
    case certificateChain = "certificate-chain"

    public static var current: InspectionScreenshotScenario? {
        ProcessInfo.processInfo.environment["INSPECT_SCREENSHOT_SCENARIO"]
            .flatMap(InspectionScreenshotScenario.init(rawValue:))
    }

    var initialURL: URL? {
        switch self {
        case .inspectTab, .monitorTab, .hostDetail, .certificateChain:
            return nil
        }
    }

    var showsAboutCard: Bool {
        false
    }

    var showsCertificateDetail: Bool {
        false
    }

    var showsDemoTargets: Bool {
        self == .inspectTab
    }

    var showsRecents: Bool {
        false
    }

    var showsMonitorCard: Bool {
        false
    }
}
