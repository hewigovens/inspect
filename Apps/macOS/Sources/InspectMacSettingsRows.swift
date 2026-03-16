import SwiftUI

struct InspectMacSettingsValueRow<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        LabeledContent {
            content
        } label: {
            InspectMacSettingsIconLabel(
                title: title,
                systemImage: systemImage,
                tint: tint
            )
        }
    }
}

struct InspectMacSettingsNavigationRow<Destination: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            InspectMacSettingsIconLabel(
                title: title,
                systemImage: systemImage,
                tint: tint
            )
        }
    }
}

struct InspectMacSettingsActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                InspectMacSettingsIconLabel(
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
