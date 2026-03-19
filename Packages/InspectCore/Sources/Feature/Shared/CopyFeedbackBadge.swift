import SwiftUI

struct CopyFeedbackBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.inspectDetailCaptionSemibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.78), in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}
