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

public struct InspectIconTile: View {
    let symbol: String
    let tint: Color
    let size: CGFloat
    let cornerRadius: CGFloat
    let font: Font

    public init(
        symbol: String,
        tint: Color,
        size: CGFloat = 38,
        cornerRadius: CGFloat? = nil,
        font: Font = .system(size: 16, weight: .semibold)
    ) {
        self.symbol = symbol
        self.tint = tint
        self.size = size
        self.cornerRadius = cornerRadius ?? (size * 0.32)
        self.font = font
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(font)
                    .foregroundStyle(tint)
            }
    }
}

struct SmallFeatureGlyph: View {
    let symbol: String
    let tint: Color

    var body: some View {
        InspectIconTile(
            symbol: symbol,
            tint: tint,
            size: 38,
            cornerRadius: 12,
            font: .inspectRootSubheadlineSemibold
        )
    }
}
