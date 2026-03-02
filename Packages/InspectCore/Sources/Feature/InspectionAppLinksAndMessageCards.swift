import SwiftUI

struct InspectionAppLinksCard: View {
    @Environment(\.openURL) private var openURL

    let appVersionText: String

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("About")
                    .font(.inspectRootHeadline)

                appLinkRow(
                    title: "About Inspect",
                    subtitle: appVersionText,
                    systemImage: "info.circle",
                    tint: .blue,
                    destination: AppLinks.about
                )

                appLinkRow(
                    title: "Rate on App Store",
                    subtitle: "Open the App Store listing",
                    systemImage: "star.bubble",
                    tint: .orange,
                    destination: AppLinks.appStore
                )
            }
        }
    }

    private func appLinkRow(title: String, subtitle: String, systemImage: String, tint: Color, destination: URL?) -> some View {
        Button {
            guard let destination else {
                return
            }

            openURL(destination)
        } label: {
            HStack(spacing: 12) {
                SmallFeatureGlyph(symbol: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.inspectRootSubheadlineSemibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.inspectRootCaptionBold)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct InspectionMessageCard: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "exclamationmark.triangle.fill")
                    .font(.inspectRootHeadline)
                    .foregroundStyle(tint)
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
