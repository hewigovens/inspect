import SwiftUI

struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.inspectRootCaptionSemibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.13), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct SmallFeatureGlyph: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: symbol)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(tint)
            }
    }
}
