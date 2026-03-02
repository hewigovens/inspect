import Foundation

public struct SecurityAssessment: Sendable, Equatable {
    public let findings: [SecurityFinding]

    public init(findings: [SecurityFinding]) {
        self.findings = findings
    }

    public var criticalCount: Int {
        findings.filter { $0.severity == .critical }.count
    }

    public var warningCount: Int {
        findings.filter { $0.severity == .warning }.count
    }

    public var infoCount: Int {
        findings.filter { $0.severity == .info }.count
    }

    public var goodCount: Int {
        findings.filter { $0.severity == .good }.count
    }

    public var headline: String {
        if criticalCount > 0 {
            return "\(criticalCount) critical signal\(criticalCount == 1 ? "" : "s")"
        }

        if warningCount > 0 {
            return "\(warningCount) warning\(warningCount == 1 ? "" : "s")"
        }

        if findings.isEmpty {
            return "No security findings"
        }

        return "Security checks completed"
    }

    public var showsHeadline: Bool {
        criticalCount > 0 || warningCount > 0
    }
}

public struct SecurityFinding: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let severity: SecurityFindingSeverity
    public let title: String
    public let message: String

    public init(severity: SecurityFindingSeverity, title: String, message: String) {
        self.severity = severity
        self.title = title
        self.message = message
    }
}

public enum SecurityFindingSeverity: String, Sendable {
    case good = "Good"
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
}
