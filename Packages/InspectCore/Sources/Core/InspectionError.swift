import Foundation

public enum InspectionError: LocalizedError, Sendable {
    case invalidURL(String)
    case unsupportedScheme(String?)
    case missingServerTrust

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let raw):
            return "'\(raw)' is not a valid HTTPS URL."
        case .unsupportedScheme(let scheme):
            return "Only HTTPS URLs are supported. Received: \(scheme ?? "unknown")."
        case .missingServerTrust:
            return "The TLS handshake finished without exposing a server trust chain."
        }
    }
}
