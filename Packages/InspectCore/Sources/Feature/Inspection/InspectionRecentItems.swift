import InspectCore
import Foundation

enum RecentInputFormatter {
    static func host(for recent: String) -> String? {
        (try? URLInputNormalizer.normalize(input: recent).host) ?? URL(string: recent)?.host
    }

    static func primaryText(for recent: String) -> String {
        guard let url = try? URLInputNormalizer.normalize(input: recent) else {
            return recent
        }

        return url.host ?? recent
    }

    static func secondaryText(for recent: String) -> String? {
        guard let url = try? URLInputNormalizer.normalize(input: recent) else {
            return nil
        }

        let path = url.path == "/" ? "" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let tail = path + query
        return tail.isEmpty ? nil : tail
    }
}

struct RecentLookupItem: Identifiable, Equatable {
    let rawInput: String
    let normalizedURL: URL?
    let host: String?
    let primaryText: String
    let secondaryText: String?

    init(_ recent: String) {
        rawInput = recent
        normalizedURL = try? URLInputNormalizer.normalize(input: recent)
        host = RecentInputFormatter.host(for: recent)
        primaryText = RecentInputFormatter.primaryText(for: recent)
        secondaryText = RecentInputFormatter.secondaryText(for: recent)
    }

    var id: String {
        normalizedURL?.absoluteString ?? rawInput
    }
}
