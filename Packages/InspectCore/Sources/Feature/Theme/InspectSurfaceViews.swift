import SwiftUI

struct InspectBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                .inspectBackgroundStart,
                .inspectBackgroundMiddle,
                .inspectBackgroundEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.inspectGlow, Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .frame(width: 220, height: 220)
                .offset(x: 60, y: -40)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.inspectShapeTint, Color.clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 260, height: 220)
                .rotationEffect(.degrees(-18))
                .offset(x: -80, y: 80)
        }
    }
}

struct InspectCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.inspectCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.inspectCardStroke, lineWidth: 1)
        )
        .shadow(color: .inspectCardShadow, radius: 10, y: 6)
    }
}
