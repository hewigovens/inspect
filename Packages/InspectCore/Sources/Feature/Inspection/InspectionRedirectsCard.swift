import InspectCore
import SwiftUI

struct InspectionRedirectsCard: View {
    let inspection: TLSInspection
    @Binding var selectedReportIndex: Int

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Redirects")
                    .font(.inspectRootHeadline)

                ForEach(Array(inspection.reports.enumerated()), id: \.element.id) { index, report in
                    Button {
                        selectedReportIndex = index
                    } label: {
                        HStack(spacing: 12) {
                            Text("Hop \(index + 1)")
                                .font(.inspectRootCaption)
                                .foregroundStyle(.secondary)

                            Text(report.host)
                                .font(.inspectRootSubheadlineSemibold)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let badgeTitle = badgeTitle(for: index) {
                                Badge(
                                    text: badgeTitle,
                                    tint: index == 0 ? .blue : .indigo
                                )
                            }

                            if selectedReportIndex == index {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.inspectAccent)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if inspection.reports.indices.contains(index + 1) {
                        Divider()
                    }
                }
            }
        }
    }

    private func badgeTitle(for index: Int) -> String? {
        if index == 0 {
            return "Origin"
        }
        if index == inspection.reports.count - 1 {
            return "Final"
        }
        return nil
    }
}
