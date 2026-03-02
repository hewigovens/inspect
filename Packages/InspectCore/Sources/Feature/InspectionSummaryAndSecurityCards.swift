import InspectCore
import SwiftUI

struct InspectionSummaryCard: View {
    let report: TLSInspectionReport

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(report.host)
                    .font(.inspectRootTitle3)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Badge(text: report.trust.badgeText, tint: report.trust.isTrusted ? .green : .orange)
                    Badge(text: protocolTitle, tint: .blue)
                    Badge(text: "\(report.certificates.count) cert\(report.certificates.count == 1 ? "" : "s")", tint: .indigo)
                    if report.security.criticalCount > 0 {
                        Badge(text: "\(report.security.criticalCount) critical", tint: .red)
                    } else if report.security.warningCount > 0 {
                        Badge(text: "\(report.security.warningCount) warning", tint: .orange)
                    }
                }

                if let leaf = report.leafCertificate {
                    LabeledContent("Issued To", value: leaf.subjectSummary)
                    LabeledContent("Issued By", value: leaf.issuerSummary)
                    LabeledContent("Validity", value: leaf.validity.status.rawValue)
                }

                if let failureReason = report.trust.failureReason, report.trust.isTrusted == false {
                    Text(failureReason)
                        .font(.inspectRootFootnote)
                        .foregroundStyle(.secondary)
                }

                if let sslLabsURL = report.sslLabsURL {
                    Link(destination: sslLabsURL) {
                        Label("Open in SSL Labs", systemImage: "arrow.up.right.square")
                    }
                    .font(.inspectRootSubheadlineSemibold)
                    .accessibilityIdentifier("action.open-ssllabs")
                }
            }
        }
    }

    private var protocolTitle: String {
        switch report.networkProtocolName?.lowercased() {
        case "h2":
            return "HTTP/2"
        case "h3":
            return "HTTP/3"
        case "http/1.1":
            return "HTTP/1.1"
        case let value?:
            return value.uppercased()
        default:
            return "Protocol Unknown"
        }
    }
}

struct InspectionSecurityCard: View {
    let assessment: SecurityAssessment

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Security Signals")
                        .font(.inspectRootHeadline)

                    if assessment.showsHeadline {
                        Spacer()
                        Text(assessment.headline)
                            .font(.inspectRootCaptionSemibold)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(assessment.findings) { finding in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(color(for: finding.severity))
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(finding.title)
                                .font(.inspectRootSubheadlineSemibold)
                            Text(finding.message)
                                .font(.inspectRootCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func color(for severity: SecurityFindingSeverity) -> Color {
        switch severity {
        case .good:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}
