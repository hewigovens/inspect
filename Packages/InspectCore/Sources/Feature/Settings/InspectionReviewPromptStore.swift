import Foundation
import InspectCore

enum InspectionReviewPromptStore {
    private static let promptedVersionKey = "inspect.review-prompted-version.v1"
    private static let threshold = 3

    static func recordSuccessfulInspection(_ report: TLSInspectionReport) -> Bool {
        let version = InspectionAppMetadata.version
        guard UserDefaults.standard.string(forKey: promptedVersionKey) != version else {
            return false
        }

        guard let host = normalizedHost(from: report), host.isEmpty == false else {
            return false
        }

        let hostsKey = hostsStorageKey(for: version)
        var hosts = Set(UserDefaults.standard.stringArray(forKey: hostsKey) ?? [])
        let inserted = hosts.insert(host).inserted
        if inserted {
            UserDefaults.standard.set(Array(hosts).sorted(), forKey: hostsKey)
        }

        guard hosts.count >= threshold else {
            return false
        }

        UserDefaults.standard.set(version, forKey: promptedVersionKey)
        return true
    }

    private static func hostsStorageKey(for version: String) -> String {
        "inspect.review-hosts.\(version)"
    }

    private static func normalizedHost(from report: TLSInspectionReport) -> String? {
        report.requestedURL.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
