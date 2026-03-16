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
                    destination: InspectAppLinks.about
                )

                appLinkRow(
                    title: "Rate on App Store",
                    subtitle: "Open the App Store listing",
                    systemImage: "star.bubble",
                    tint: .orange,
                    destination: InspectAppLinks.appStore
                )
            }
        }
    }

    private func appLinkRow(title: String, subtitle: String, systemImage: String, tint: Color, destination: URL) -> some View {
        Button {
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

struct InspectionWorkspaceCard: View {
    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Certificate Workspace")
                    .font(.inspectRootHeadline)

                workspaceFeature(
                    title: "Trust Summary",
                    message: "See the trust verdict, negotiated protocol, issuer, and validity at a glance.",
                    symbol: "checkmark.shield",
                    tint: .green
                )

                workspaceFeature(
                    title: "Chain Navigation",
                    message: "Open any certificate in the chain and expand into the detailed inspector view.",
                    symbol: "point.3.connected.trianglepath.dotted",
                    tint: .indigo
                )

                workspaceFeature(
                    title: "Copyable Details",
                    message: "Review fingerprints, extensions, and raw certificate data with copy actions built in.",
                    symbol: "doc.on.doc",
                    tint: .orange
                )
            }
        }
    }

    private func workspaceFeature(title: String, message: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            SmallFeatureGlyph(symbol: symbol, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.inspectRootSubheadlineSemibold)
                Text(message)
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
