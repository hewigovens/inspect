import SwiftUI

struct InspectSettingsMessageRow: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(color)
    }
}
