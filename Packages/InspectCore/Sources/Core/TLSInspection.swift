import Foundation

public struct TLSInspection: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let requestedURL: URL
    public let reports: [TLSInspectionReport]

    public init(
        id: UUID = UUID(),
        requestedURL: URL,
        reports: [TLSInspectionReport]
    ) {
        self.id = id
        self.requestedURL = requestedURL
        self.reports = reports
    }

    public init(report: TLSInspectionReport) {
        self.init(
            requestedURL: report.requestedURL,
            reports: [report]
        )
    }

    public var primaryReport: TLSInspectionReport? {
        reports.first
    }

    public var finalReport: TLSInspectionReport? {
        reports.last
    }

    public var didRedirect: Bool {
        reports.count > 1
    }

    public var combinedSecurity: SecurityAssessment {
        SecurityAssessment(findings: reports.flatMap { $0.security.findings })
    }
}
