import Foundation

public enum InspectDeepLink: Sendable, Equatable {
    case certificateDetail(token: String)

    public static let scheme = "inspect"

    public var url: URL {
        switch self {
        case let .certificateDetail(token):
            var components = URLComponents()
            components.scheme = Self.scheme
            components.host = "certificate-detail"
            components.queryItems = [
                URLQueryItem(name: "token", value: token)
            ]
            return components.url!
        }
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else {
            return nil
        }

        switch url.host?.lowercased() {
        case "certificate-detail":
            guard let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "token" })?
                .value,
                  token.isEmpty == false else {
                return nil
            }

            self = .certificateDetail(token: token)
        default:
            return nil
        }
    }
}
