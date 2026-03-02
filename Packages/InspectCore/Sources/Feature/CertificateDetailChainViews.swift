import InspectCore
import SwiftUI

struct CompactCertificateChainPanel: View {
    let nodes: [CertificateChainNode]
    let trust: TrustSummary
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { offset, node in
                Button {
                    onSelect(node.originalIndex)
                } label: {
                    CompactCertificateChainRow(
                        node: node,
                        trust: trust,
                        isSelected: selectedIndex == node.originalIndex
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    selectedIndex == node.originalIndex
                    ? Color.accentColor
                    : Color.certificateRowBackground
                )

                if offset != nodes.count - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct CompactCertificateChainRow: View {
    let node: CertificateChainNode
    let trust: TrustSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: CGFloat(node.depth) * 26, height: 1)

            SummaryGlyph(symbol: symbol, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(node.certificate.subjectSummary)
                    .font(.inspectDetailSubheadlineSemibold)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)

                Text(node.certificate.issuerSummary)
                    .font(.inspectDetailCaption)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var symbol: String {
        if leafHasFailureSignal {
            return "xmark.seal.fill"
        }
        if node.certificate.isLeaf {
            return "network"
        }
        if node.certificate.isRoot {
            return "checkmark.shield.fill"
        }
        return "seal.fill"
    }

    private var tint: Color {
        if leafHasFailureSignal {
            return .red
        }
        if node.certificate.isLeaf {
            return .blue
        }
        if node.certificate.isRoot {
            return .orange
        }
        return .indigo
    }

    private var leafHasFailureSignal: Bool {
        node.certificate.isLeaf && trust.isTrusted == false
    }
}

private struct SummaryGlyph: View {
    let symbol: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.15))
                .frame(width: 30, height: 30)

            Image(systemName: symbol)
                .font(.inspectDetailCaptionSemibold)
                .foregroundStyle(tint)
        }
    }
}
