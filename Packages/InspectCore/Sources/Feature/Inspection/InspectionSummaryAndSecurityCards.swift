import InspectCore
import SwiftUI

struct InspectionSummaryCard: View {
    @Environment(\.openURL) private var openURL
    let report: TLSInspectionReport
    let reportIndex: Int
    @State private var presentsSSLLabs = false

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Connection Summary")
                    .font(.inspectRootHeadline)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 0), spacing: badgeSpacing),
                        count: min(badges(for: selectedReport).count, InspectLayout.Summary.maxBadgesPerRow)
                    ),
                    alignment: .leading,
                    spacing: badgeSpacing
                ) {
                    ForEach(badges(for: selectedReport)) { badge in
                        Badge(text: badge.text, tint: badge.tint)
                            .frame(maxWidth: .infinity)
                    }
                }

                if let leaf = selectedReport.leafCertificate {
                    VStack(alignment: .leading, spacing: 12) {
                        InspectionSummaryField(title: "Issued To", value: leaf.subjectSummary)
                        InspectionSummaryField(title: "Issued By", value: leaf.issuerSummary)
                        InspectionSummaryField(title: "Validity", value: leaf.validity.status.rawValue)
                        if let cipherSuite = selectedReport.cipherSuite {
                            InspectionSummaryField(title: "Cipher Suite", value: cipherSuite)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let failureReason = selectedReport.trust.failureReason, selectedReport.trust.isTrusted == false {
                    Text(failureReason)
                        .font(.inspectRootFootnote)
                        .foregroundStyle(.secondary)
                }

                if let sslLabsURL = selectedReport.sslLabsURL {
                    Button {
                        openSSLLabs(sslLabsURL)
                    } label: {
                        Label("Open in SSL Labs", systemImage: "arrow.up.right.square")
                    }
                    .font(.inspectRootSubheadlineSemibold)
                    .accessibilityIdentifier("action.open-ssllabs.\(reportIndex)")
                }
            }
        }
        .inspectSafariSheet(url: selectedReport.sslLabsURL, isPresented: $presentsSSLLabs)
    }

    private func openSSLLabs(_ url: URL) {
        #if os(macOS)
            openURL(url)
        #else
            presentsSSLLabs = true
        #endif
    }

    private func protocolTitle(for report: TLSInspectionReport) -> String {
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

    private var badgeSpacing: CGFloat {
        InspectLayout.Summary.badgeSpacing
    }

    private var selectedReport: TLSInspectionReport {
        report
    }

    private func badges(for report: TLSInspectionReport) -> [InspectionSummaryBadge] {
        var values = [
            InspectionSummaryBadge(
                text: report.trust.badgeText,
                tint: report.trust.isTrusted ? .green : .orange
            ),
            InspectionSummaryBadge(text: protocolTitle(for: report), tint: .blue),
        ]

        if let tlsVersion = report.tlsVersion {
            values.append(
                InspectionSummaryBadge(
                    text: tlsVersion,
                    tint: tlsVersion.contains("1.3") ? .green : .secondary
                )
            )
        }

        values.append(
            InspectionSummaryBadge(
                text: "\(report.certificates.count) cert\(report.certificates.count == 1 ? "" : "s")",
                tint: .indigo
            )
        )

        if report.security.criticalCount > 0 {
            values.append(
                InspectionSummaryBadge(
                    text: "\(report.security.criticalCount) critical",
                    tint: .red
                )
            )
        } else if report.security.warningCount > 0 {
            values.append(
                InspectionSummaryBadge(
                    text: "\(report.security.warningCount) warning",
                    tint: .orange
                )
            )
        }

        return values
    }
}

private struct InspectionSummaryBadge: Identifiable {
    let text: String
    let tint: Color

    var id: String {
        text
    }
}

private struct InspectionSummaryField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.inspectRootCaptionBold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.inspectRootSubheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InspectionSecurityCard: View {
    let report: TLSInspectionReport

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Security Signals")
                    .font(.inspectRootHeadline)

                if report.security.findings.isEmpty {
                    Text("No security findings for this hop.")
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                } else {
                    if report.security.showsHeadline {
                        Text(report.security.headline)
                            .font(.inspectRootCaptionSemibold)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(report.security.findings) { finding in
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
