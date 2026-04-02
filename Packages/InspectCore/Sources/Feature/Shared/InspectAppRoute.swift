import Foundation
import InspectCore

public enum InspectAppRoute: Sendable, Equatable {
    case section(InspectSection)
    case toggleLiveMonitor

    public var url: URL {
        var components = URLComponents()
        components.scheme = InspectScheme.scheme

        switch self {
        case let .section(section):
            components.host = InspectScheme.sectionHost
            components.queryItems = [
                URLQueryItem(name: InspectScheme.sectionQueryItemName, value: section.rawValue.lowercased()),
            ]
        case .toggleLiveMonitor:
            components.host = InspectScheme.toggleLiveMonitorHost
        }

        return components.url!
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == InspectScheme.scheme else {
            return nil
        }

        switch url.host?.lowercased() {
        case InspectScheme.sectionHost:
            guard let rawSection = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == InspectScheme.sectionQueryItemName })?
                .value
            else {
                return nil
            }

            switch rawSection.lowercased() {
            case "inspect":
                self = .section(.inspect)
            case "monitor":
                self = .section(.monitor)
            case "settings":
                self = .section(.settings)
            default:
                return nil
            }
        case InspectScheme.toggleLiveMonitorHost:
            self = .toggleLiveMonitor
        default:
            return nil
        }
    }
}
