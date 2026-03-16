import Foundation
import InspectCore

enum SafariWebExtensionPayload {
    static func success(for report: TLSInspectionReport) -> [String: Any] {
        let leaf = report.leafCertificate
        let reportToken = try? InspectionSharedReportStore.save(report)
        let tone: String

        if report.security.criticalCount > 0 || report.trust.isTrusted == false {
            tone = "critical"
        } else if report.security.warningCount > 0 {
            tone = "warning"
        } else {
            tone = "good"
        }

        let trustSummary = report.trust.isTrusted
            ? "The platform trust engine accepted the chain."
            : (report.trust.failureReason ?? "The platform trust engine rejected the chain.")

        return [
            "status": "success",
            "tone": tone,
            "host": report.host,
            "url": report.requestedURL.absoluteString,
            "protocolName": report.networkProtocolName ?? "Unknown",
            "trustBadge": report.trust.badgeText,
            "trustSummary": trustSummary,
            "securityHeadline": report.security.headline,
            "criticalCount": report.security.criticalCount,
            "warningCount": report.security.warningCount,
            "commonName": leaf?.commonNames.first ?? leaf?.subjectSummary ?? report.host,
            "issuerSummary": leaf?.issuerSummary ?? "Unknown issuer",
            "validityStatus": leaf?.validity.status.rawValue ?? "Unknown",
            "validUntil": formattedDate(leaf?.validity.notAfter),
            "reportToken": reportToken ?? "",
            "chainNames": report.certificates.map(\.subjectSummary),
            "topFindingTitle": report.security.findings.first?.title ?? "",
            "topFindingMessage": report.security.findings.first?.message ?? ""
        ]
    }

    static func error(_ message: String) -> [String: Any] {
        [
            "status": "error",
            "message": message
        ]
    }

    private static func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "Unknown"
        }

        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }
}
