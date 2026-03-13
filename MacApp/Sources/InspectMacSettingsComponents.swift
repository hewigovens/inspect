import SwiftUI

struct InspectMacSettingsIconLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.15))

                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            Text(title)
        }
    }
}

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

struct InspectMacSettingsMessageRow: View {
    let message: String
    let systemImage: String
    let foregroundStyle: AnyShapeStyle

    init(message: String, systemImage: String, color: Color) {
        self.message = message
        self.systemImage = systemImage
        self.foregroundStyle = AnyShapeStyle(color)
    }

    init(message: String, systemImage: String, hierarchicalStyle: HierarchicalShapeStyle) {
        self.message = message
        self.systemImage = systemImage
        self.foregroundStyle = AnyShapeStyle(hierarchicalStyle)
    }

    var body: some View {
        Label(message, systemImage: systemImage)
            .foregroundStyle(foregroundStyle)
    }
}
