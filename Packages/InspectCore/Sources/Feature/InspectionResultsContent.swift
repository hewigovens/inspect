import InspectCore
import SwiftUI

struct InspectionResultsContent: View {
    let isLoading: Bool
    let errorMessage: String?
    let report: TLSInspectionReport?
    let recentItems: [RecentLookupItem]
    let currentReportURL: URL?
    let onInspectRecent: (String) async -> Void
    let onClearRecents: () -> Void
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

            if let report {
                InspectionSummaryCard(report: report)
                    .id("summary")
                InspectionSecurityCard(assessment: report.security)
                    .id("security")
                InspectionChainCard(report: report)
                    .id("chain")
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
}
