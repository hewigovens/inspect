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

public struct InspectSettingsValueRow<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    public init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
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

public struct InspectSettingsNavigationRow<Destination: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let destination: Destination

    public init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.destination = destination()
    }

    public var body: some View {
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

public struct InspectSettingsActionRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    public init(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    public var body: some View {
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

public struct InspectSettingsMessageRow: View {
    let message: String
    let systemImage: String
    let foregroundStyle: AnyShapeStyle

    public init(message: String, systemImage: String, color: Color) {
        self.message = message
        self.systemImage = systemImage
        self.foregroundStyle = AnyShapeStyle(color)
    }

    public init(message: String, systemImage: String, hierarchicalStyle: HierarchicalShapeStyle) {
        self.message = message
        self.systemImage = systemImage
        self.foregroundStyle = AnyShapeStyle(hierarchicalStyle)
    }

    public var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(foregroundStyle)
    }
}
