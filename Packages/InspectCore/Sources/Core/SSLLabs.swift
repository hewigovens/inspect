import Foundation

enum SSLLabs {
    static let analyzeBaseURL = "https://www.ssllabs.com/ssltest/analyze.html"

    static func analyzeURL(host: String) -> URL? {
        var components = URLComponents(string: analyzeBaseURL)
        components?.queryItems = [
            URLQueryItem(name: "hideResults", value: "on"),
            URLQueryItem(name: "d", value: host),
        ]
        return components?.url
    }
}
