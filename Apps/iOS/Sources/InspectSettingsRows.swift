import InspectFeature
import SwiftUI

struct InspectSettingsIconLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InspectIconTile(
                symbol: systemImage,
                tint: tint,
                size: 28,
                cornerRadius: 9,
                font: .system(size: 14, weight: .semibold)
            )

            Text(title)
        }
    }
}

struct InspectSettingsValueRow<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        LabeledContent {
            content
        } label: {
            InspectSettingsIconLabel(
                title: title,
                systemImage: systemImage,
                tint: tint
            )
        }
    }
}

struct InspectSettingsNavigationRow<Destination: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            InspectSettingsIconLabel(
                title: title,
                systemImage: systemImage,
                tint: tint
            )
        }
    }
}

struct InspectSettingsActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                InspectSettingsIconLabel(
                    title: title,
                    systemImage: systemImage,
                    tint: tint
                )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
