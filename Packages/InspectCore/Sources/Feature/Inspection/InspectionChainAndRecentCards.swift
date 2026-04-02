import InspectCore
import SwiftUI

@MainActor
protocol InspectionChainActions {
    func openCertificateDetail(inspection: TLSInspection, reportIndex: Int, certificateIndex: Int)
}

struct InspectionChainCard: View {
    let inspection: TLSInspection
    let selectedReportIndex: Int
    let actions: InspectionChainActions

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Certificate Chain")
                    .font(.inspectRootHeadline)

                ForEach(Array(selectedReport.certificates.enumerated()), id: \.element.id) { certificateIndex, certificate in
                    certificateRow(
                        certificate: certificate,
                        report: selectedReport,
                        reportIndex: selectedReportIndex,
                        certificateIndex: certificateIndex
                    )
                }
            }
        }
    }

    private func certificateRow(
        certificate: CertificateDetails,
        report: TLSInspectionReport,
        reportIndex: Int,
        certificateIndex: Int
    ) -> some View {
        Button {
            actions.openCertificateDetail(
                inspection: inspection,
                reportIndex: reportIndex,
                certificateIndex: certificateIndex
            )
        } label: {
            CertificateRow(
                certificate: certificate,
                reportTrust: report.trust
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("chain.hop.\(reportIndex).certificate.\(certificateIndex)")
    }

    private var selectedReport: TLSInspectionReport {
        inspection.reports[selectedReportIndex]
    }
}

@MainActor
protocol InspectionRecentActions {
    func inspectRecent(_ input: String) async
    func removeRecent(_ input: String)
    func clearRecents()
}

struct InspectionRecentCard: View {
    let items: [RecentLookupItem]
    let currentReportURL: URL?
    let actions: InspectionRecentActions
    let isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recents")
                        .font(.inspectRootHeadline)

                    Spacer()

                    Button("Clear") { actions.clearRecents() }
                        .font(.inspectRootCaptionSemibold)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.clear-recents")
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, recent in
                    recentRow(recent: recent, index: index)
                }
            }
        }
    }

    private func recentRow(recent: RecentLookupItem, index: Int) -> some View {
        let isCurrent = recent.normalizedURL == currentReportURL

        return Button {
            isInputFocused.wrappedValue = false
            Task {
                await actions.inspectRecent(recent.rawInput)
            }
        } label: {
            HStack(spacing: 12) {
                RecentLookupIcon(host: recent.host)

                VStack(alignment: .leading, spacing: 3) {
                    Text(recent.primaryText)
                        .font(.inspectRootSubheadlineSemibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let secondaryText = recent.secondaryText {
                        Text(secondaryText)
                            .font(.inspectRootCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isCurrent {
                    Text("Current")
                        .font(.inspectRootCaptionSemibold)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("recent.\(index)")
        .contextMenu {
            Button(role: .destructive) {
                actions.removeRecent(recent.rawInput)
            } label: {
                Label("Delete lookup", systemImage: "trash")
            }
        }
    }
}

struct InspectionRecentPlaceholderCard: View {
    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recents")
                    .font(.inspectRootHeadline)

                Text("Recent inspections will appear here after you inspect a host.")
                    .font(.inspectRootFootnote)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 12) {
                    SmallFeatureGlyph(symbol: "clock.arrow.circlepath", tint: .blue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quick reruns")
                            .font(.inspectRootSubheadlineSemibold)
                        Text("Use recent hosts to repeat an inspection without retyping the URL.")
                            .font(.inspectRootCaption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
