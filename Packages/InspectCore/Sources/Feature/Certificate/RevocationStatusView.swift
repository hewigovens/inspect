import InspectCore
import SwiftUI

struct RevocationStatusBadge: View {
    let summary: CertificateRevocationSummary

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: summary.iconName)
                .foregroundStyle(tint)
                .font(.body)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.title)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)

                if let detail = summary.detail {
                    Text(detail)
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if summary.showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .animation(nil, value: summary)
    }

    private var tint: Color {
        switch summary.tone {
        case .neutral: return .secondary
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
