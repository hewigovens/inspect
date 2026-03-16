import Foundation

public enum InspectSection: String, CaseIterable, Hashable, Identifiable, Sendable {
    case inspect = "Inspect"
    case monitor = "Monitor"
    case settings = "Settings"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var systemImage: String {
        switch self {
        case .inspect:
            return "magnifyingglass.circle"
        case .monitor:
            return "wave.3.right.circle"
        case .settings:
            return "gearshape"
        }
    }
}
