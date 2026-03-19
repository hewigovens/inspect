#if os(macOS)
import SwiftUI

struct MacCertificateSectionCard: View {
    let section: CertificateDetailSection
    let onCopy: (DetailLine) -> Void

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.bottom, 6)

                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    Group {
                        switch row.style {
                        case .inline:
                            MacInlineDetailRow(row: row) {
                                onCopy(row)
                            }
                        case .stacked:
                            MacStackedDetailRow(row: row) {
                                onCopy(row)
                            }
                        }
                    }

                    if index != section.rows.count - 1 {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

private struct MacInlineDetailRow: View {
    let row: DetailLine
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(row.label)
                .font(.inspectDetailCompactCaptionSemibold)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(row.value)
                .font(.inspectDetailCompactBody)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)

            copyButton
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Copy Value", systemImage: "doc.on.doc", action: onCopy)
        }
    }

    private var copyButton: some View {
        Button(action: onCopy) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Copy \(row.label)")
    }
}

private struct MacStackedDetailRow: View {
    let row: DetailLine
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(row.label)
                    .font(.inspectDetailCompactCaptionSemibold)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.inspectDetailCompactCaptionSemibold)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.value)
                .font(row.monospaced ? .inspectDetailCompactMonospaced : .inspectDetailCompactBody)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.inspectChromeFill)
                )
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Copy Value", systemImage: "doc.on.doc", action: onCopy)
        }
    }
}
#endif
