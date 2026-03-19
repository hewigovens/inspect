#if os(macOS)
import SwiftUI

struct MacCertificateQuickFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.inspectDetailCompactCaptionSemibold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.inspectDetailCompactBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MacCertificateStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.inspectDetailCompactCaption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.inspectDetailCompactBodySemibold)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.inspectChromeFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
#endif
