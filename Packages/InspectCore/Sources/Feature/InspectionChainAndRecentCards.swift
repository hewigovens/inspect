import InspectCore
import SwiftUI

struct InspectionChainCard: View {
    let report: TLSInspectionReport
    let onOpenCertificateDetail: (TLSInspectionReport, Int) -> Void
    @State private var pendingSelectionIndex: Int?

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Certificate Chain")
                    .font(.inspectRootHeadline)

                ForEach(Array(report.certificates.enumerated()), id: \.element.id) { index, certificate in
                    certificateRow(certificate: certificate, at: index)
                }
            }
        }
    }

    @ViewBuilder
    private func certificateRow(certificate: CertificateDetails, at index: Int) -> some View {
        #if os(macOS)
        Button {
            guard pendingSelectionIndex == nil else {
                return
            }

            pendingSelectionIndex = index
            InspectionWindowLayoutCenter.post(.certificateDetail)

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(130))
                onOpenCertificateDetail(report, index)
                pendingSelectionIndex = nil
            }
        } label: {
            CertificateRow(
                certificate: certificate,
                reportTrust: report.trust
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(pendingSelectionIndex != nil)
        .accessibilityIdentifier("chain.certificate.\(index)")
        #else
        Button {
            onOpenCertificateDetail(report, index)
        } label: {
            CertificateRow(
                certificate: certificate,
                reportTrust: report.trust
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier("chain.certificate.\(index)")
        #endif
    }
}

struct InspectionRecentCard: View {
    let items: [RecentLookupItem]
    let currentReportURL: URL?
    let onInspectRecent: (String) async -> Void
    let onClearRecents: () -> Void
    let isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recents")
                        .font(.inspectRootHeadline)

                    Spacer()

                    Button("Clear", action: onClearRecents)
                        .font(.inspectRootCaptionSemibold)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.clear-recents")
                }

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
