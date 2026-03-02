import InspectCore
import SwiftUI

struct InspectionChainCard: View {
    let report: TLSInspectionReport

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Certificate Chain")
                    .font(.inspectRootHeadline)

                ForEach(Array(report.certificates.enumerated()), id: \.element.id) { index, certificate in
                    NavigationLink {
                        CertificateDetailView(
                            report: report,
                            initialSelectionIndex: index
                        )
                    } label: {
                        CertificateRow(
                            certificate: certificate,
                            reportTrust: report.trust
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("chain.certificate.\(index)")
                }
            }
        }
    }
}

struct InspectionRecentCard: View {
    let items: [RecentLookupItem]
    let currentReportURL: URL?
    let onInspectRecent: (String) async -> Void
    let isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recents")
                    .font(.inspectRootHeadline)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, recent in
                    let isCurrent = recent.normalizedURL == currentReportURL

                    Button {
                        isInputFocused.wrappedValue = false
                        Task {
                            await onInspectRecent(recent.rawInput)
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
                            } else {
                                Image(systemName: "arrow.clockwise")
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
                }
            }
        }
    }
}
