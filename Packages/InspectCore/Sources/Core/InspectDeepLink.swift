import Foundation

public enum InspectDeepLink: Sendable, Equatable {
    case certificateDetail(token: String)

    public var url: URL {
        switch self {
        case let .certificateDetail(token):
            var components = URLComponents()
            components.scheme = InspectScheme.scheme
            components.host = InspectScheme.certificateDetailHost
            components.queryItems = [
                URLQueryItem(name: InspectScheme.tokenQueryItemName, value: token),
            ]
            return components.url!
        }
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == InspectScheme.scheme else {
            return nil
        }

        switch url.host?.lowercased() {
        case InspectScheme.certificateDetailHost:
            guard let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == InspectScheme.tokenQueryItemName })?
                .value,
                token.isEmpty == false
            else {
                return nil
            }

            self = .certificateDetail(token: token)
        default:
            return nil
        }
    }
}
