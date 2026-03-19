import SwiftUI

public struct InspectSettingsIconLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    public init(title: String, systemImage: String, tint: Color) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InspectIconTile(
                symbol: systemImage,
                tint: tint,
                size: 28,
                cornerRadius: settingsIconCornerRadius,
                font: .system(size: settingsIconFontSize, weight: .semibold)
            )

            Text(title)
        }
    }

    private var settingsIconCornerRadius: CGFloat {
        #if os(macOS)
        8
        #else
        9
        #endif
    }

    private var settingsIconFontSize: CGFloat {
        #if os(macOS)
        13
        #else
        14
        #endif
    }
}
