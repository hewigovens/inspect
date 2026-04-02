import InspectCore
import SwiftUI

struct InspectionResultsContent: View {
    let isLoading: Bool
    let errorMessage: String?
    let inspection: TLSInspection?
    @Binding var selectedReportIndex: Int
    let recentItems: [RecentLookupItem]
    let currentReportURL: URL?
    let onInspectRecent: (String) async -> Void
    let onClearRecents: () -> Void
    let onOpenCertificateDetail: (TLSInspection, Int, Int) -> Void
    let isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        Group {
            if isLoading {
                InspectionLoadingCard()
                    .id("loading")
            }

            if let errorMessage {
                InspectionMessageCard(
                    title: "Inspection Failed",
                    message: errorMessage,
                    tint: .orange
                )
                .id("error")
            }

            if let inspection, let report = selectedReport {
                if inspection.didRedirect {
                    InspectionRedirectsCard(
                        inspection: inspection,
                        selectedReportIndex: $selectedReportIndex
                    )
                    .id("hop-picker")
                }

                InspectionChainCard(
                    inspection: inspection,
                    selectedReportIndex: selectedReportIndex,
                    onOpenCertificateDetail: onOpenCertificateDetail
                )
                .id("chain")
                InspectionSummaryCard(
                    report: report,
                    reportIndex: selectedReportIndex
                )
                .id("summary")
                InspectionSecurityCard(report: report)
                    .id("security")
            }

            if recentItems.isEmpty == false {
                InspectionRecentCard(
                    items: recentItems,
                    currentReportURL: currentReportURL,
                    onInspectRecent: onInspectRecent,
                    onClearRecents: onClearRecents,
                    isInputFocused: isInputFocused
                )
                .id("recents")
            }
        }
    }

    private var selectedReport: TLSInspectionReport? {
        inspection?.reports[safe: min(selectedReportIndex, (inspection?.reports.count ?? 1) - 1)]
    }
}
