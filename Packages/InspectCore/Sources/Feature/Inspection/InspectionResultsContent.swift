import InspectCore
import SwiftUI

@MainActor
protocol InspectionResultsActions: InspectionChainActions, InspectionRecentActions {}

struct InspectionResultsContent: View {
    let isLoading: Bool
    let errorMessage: String?
    let inspection: TLSInspection?
    @Binding var selectedReportIndex: Int
    let recentItems: [RecentLookupItem]
    let currentReportURL: URL?
    let delegate: InspectionResultsActions
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
                    actions: delegate
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

            if !recentItems.isEmpty {
                InspectionRecentCard(
                    items: recentItems,
                    currentReportURL: currentReportURL,
                    actions: delegate,
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
