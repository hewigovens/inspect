import SwiftUI

struct InlineDetailRow: View {
    let label: String
    let value: String
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.inspectDetailSubheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            Text(value)
                .font(.inspectDetailSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Value", systemImage: "doc.on.doc", action: onCopy)
        }
        .accessibilityHint("Long press to copy the value")
    }
}

struct StackedDetailRow: View {
    let label: String
    let value: String
    let monospaced: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.inspectDetailCaptionSemibold)
                .foregroundStyle(.secondary)

            if monospaced {
                Text(value)
                    .font(.inspectDetailFootnoteMonospaced)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(value)
                    .font(.inspectDetailSubheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Value", systemImage: "doc.on.doc", action: onCopy)
        }
        .accessibilityHint("Long press to copy the value")
    }
}
