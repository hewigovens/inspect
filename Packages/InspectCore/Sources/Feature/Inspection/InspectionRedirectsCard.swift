import InspectCore
import SwiftUI

struct InspectionRedirectsCard: View {
    let inspection: TLSInspection
    @Binding var selectedReportIndex: Int

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Redirects")
                    .font(.inspectRootHeadline)
                    .padding(.bottom, 14)

                ForEach(Array(inspection.reports.enumerated()), id: \.element.id) { index, report in
                    if index > 0 {
                        Divider()
                    }

                    Button {
                        selectedReportIndex = index
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.inspectRootSubheadlineSemibold)
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
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
