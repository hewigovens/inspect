import InspectKit
import SwiftUI

struct InspectMacSettingsIconLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            InspectIconTile(
                symbol: systemImage,
                tint: tint,
                size: 28,
                cornerRadius: 8,
                font: .system(size: 13, weight: .semibold)
            )

            Text(title)
        }
    }
}
