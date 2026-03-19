import SwiftUI

public struct InspectDiagnosticsSettingsSection: View {
    let verboseTunnelLogsBinding: Binding<Bool>
    let footerText: String

    public init(verboseTunnelLogsBinding: Binding<Bool>, footerText: String? = nil) {
        self.verboseTunnelLogsBinding = verboseTunnelLogsBinding
        self.footerText = footerText ?? InspectionSettingsStrings.Shared.verboseFooter
    }

    public var body: some View {
        Section {
            InspectSettingsNavigationRow(
                title: InspectionSettingsStrings.Shared.events,
                systemImage: "waveform.path.ecg",
                tint: .orange
            ) {
                InspectionEventsView()
            }

            InspectSettingsNavigationRow(
                title: InspectionSettingsStrings.Shared.tunnelLog,
                systemImage: "doc.text.magnifyingglass",
                tint: .orange
            ) {
                InspectionTunnelLogView()
            }

            Toggle(isOn: verboseTunnelLogsBinding) {
                InspectSettingsIconLabel(
                    title: InspectionSettingsStrings.Shared.verbose,
                    systemImage: "ladybug",
                    tint: .pink
                )
            }
        } header: {
            Text(InspectionSettingsStrings.Shared.diagnostics)
        } footer: {
            Text(footerText)
        }
    }
}

public struct InspectAboutSettingsSection: View {
    let openURL: OpenURLAction

    @State private var reviewDebugTrigger = InspectionReviewDebugTrigger()

    public init(openURL: OpenURLAction) {
        self.openURL = openURL
    }

    public var body: some View {
        Section(InspectionSettingsStrings.Shared.about) {
            Button {
                if reviewDebugTrigger.registerTap() {
                    InspectReviewRequester.requestReview()
                }
            } label: {
                HStack(spacing: 0) {
                    InspectSettingsIconLabel(
                        title: InspectionSettingsStrings.Shared.version,
                        systemImage: "app.badge",
                        tint: .blue
                    )

                    Spacer(minLength: 12)

                    Text(InspectionAppMetadata.versionBuildText)
                        .font(versionFont)
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            InspectSettingsActionRow(
                title: InspectionSettingsStrings.Shared.aboutInspect,
                systemImage: "info.circle",
                tint: .indigo
            ) {
                openURL(InspectAppLinks.about)
            }

            InspectSettingsActionRow(
                title: InspectionSettingsStrings.Shared.rateOnAppStore,
                systemImage: "star.circle",
                tint: .yellow
            ) {
                openURL(InspectAppLinks.appStore)
            }
        }
    }

    private var versionFont: Font {
        #if os(macOS)
        .body.weight(.medium)
        #else
        .subheadline.weight(.medium)
        #endif
    }
}
