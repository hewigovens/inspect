import Foundation

public enum URLInputNormalizer {
    public static func normalize(input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw InspectionError.invalidURL(input)
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate) else {
            throw InspectionError.invalidURL(trimmed)
        }

        return try normalize(url: url)
    }

    public static func normalize(url: URL) throws -> URL {
        guard url.scheme?.lowercased() == "https" else {
            throw InspectionError.unsupportedScheme(url.scheme)
        }

        guard let host = url.host, host.isEmpty == false else {
            throw InspectionError.invalidURL(url.absoluteString)
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.path.isEmpty ?? true {
            components?.path = "/"
        }

        guard let normalized = components?.url else {
            throw InspectionError.invalidURL(url.absoluteString)
        }

        return normalized
    }
}
