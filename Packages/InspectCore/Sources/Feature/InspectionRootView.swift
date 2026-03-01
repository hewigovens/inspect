import InspectCore
import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct InspectionRootView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("inspect.dismiss-demo-target") private var dismissDemoTarget = false
    @FocusState private var isInputFocused: Bool
    @State private var store = InspectionStore()

    private let initialURL: URL?
    private let closeAction: (() -> Void)?
    private let presentation: InspectionPresentation

    public init(
        initialURL: URL? = nil,
        closeAction: (() -> Void)? = nil,
        presentation: InspectionPresentation = .app
    ) {
        self.initialURL = initialURL
        self.closeAction = closeAction
        self.presentation = presentation
    }

    public var body: some View {
        NavigationStack {
            content
        }
        .tint(.inspectAccent)
        .task(id: initialURL?.absoluteString) {
            store.bootstrap(initialURL: initialURL)
        }
    }

    @ViewBuilder
    private var content: some View {
        if presentation == .actionExtension, let report = store.report {
            CertificateDetailView(report: report, initialSelectionIndex: 0)
                .toolbar {
                    if let closeAction {
                        #if os(iOS)
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done", action: closeAction)
                        }
                        #else
                        ToolbarItem {
                            Button("Done", action: closeAction)
                        }
                        #endif
                    }
                }
        } else if presentation == .actionExtension, initialURL != nil {
            extensionInspectionContent
        } else {
            rootContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .hideRootNavigationBar()
        }
    }

    private var rootContent: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            InspectBackground()
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 18) {
                    pageHeader
                        .id("header")

                    inputCard
                        .id("input")

                    if store.isLoading {
                        loadingCard
                            .id("loading")
                    }

                    if let errorMessage = store.errorMessage {
                        messageCard(
                            title: "Inspection Failed",
                            message: errorMessage,
                            tint: .orange
                        )
                        .id("error")
                    }

                    if let report = store.report {
                        summaryCard(report)
                            .id("summary")
                        securityCard(report.security)
                            .id("security")
                        chainCard(report)
                            .id("chain")
                    }

                    if store.recentInputs.isEmpty == false {
                        recentCard
                            .id("recents")
                    }

                    appLinksCard
                        .id("about")
                }
                .padding(.horizontal, 20)
                .padding(.top, presentation.topPadding)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
            .applyExtensionScrollMargins(presentation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            isInputFocused = false
        }
    }

    private var extensionInspectionContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.input.isEmpty ? (initialURL?.host ?? initialURL?.absoluteString ?? "Preparing inspection") : store.input)
                        .font(.inspectRootHeadline)

                    Text("Opening the shared page and reading the presented TLS chain.")
                        .font(.inspectRootSubheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Current Page")
            }

            if store.isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Inspecting certificate chain")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorMessage = store.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Inspection Failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.inspectRootSubheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Try Again") {
                        Task {
                            await store.inspectCurrentInput()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .extensionGroupedListStyle()
        .navigationTitle("Certificate")
        .inlineRootNavigationTitle()
        .toolbar {
            if let closeAction {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: closeAction)
                }
                #else
                ToolbarItem {
                    Button("Done", action: closeAction)
                }
                #endif
            }
        }
    }

    private var inputCard: some View {
        let inputBinding = Binding(
            get: { store.input },
            set: { store.input = $0 }
        )

        return InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Enter a host name or HTTPS URL.")
                    .font(.inspectRootSubheadline)
                    .foregroundStyle(.secondary)

                if dismissDemoTarget == false {
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            isInputFocused = false
                            inputBinding.wrappedValue = "https://hewig.dev"
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.inspectRootHeadline)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use Demo Target")
                                        .font(.inspectRootCaptionBold)
                                    Text("hewig.dev")
                                        .font(.inspectRootSubheadlineSemibold)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.inspectAccent)
                        .controlSize(.large)
                        .accessibilityIdentifier("action.fill-example")

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismissDemoTarget = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.inspectRootCaptionBold)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color.inspectChromeMutedFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.dismiss-demo-target")
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                TextField("hewig.dev", text: inputBinding)
                    .inspectURLField()
                    .focused($isInputFocused)
                    .lineLimit(1)
                    .padding(14)
                    .background(Color.inspectChromeFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("input.url")
                    .onSubmit {
                        isInputFocused = false
                        Task {
                            await store.inspectCurrentInput()
                        }
                    }

                HStack(spacing: 12) {
                    Button {
                        isInputFocused = false
                        #if canImport(UIKit)
                        if let pasted = UIPasteboard.general.string {
                            store.input = pasted
                        }
                        #endif
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(.inspectRootSubheadlineSemibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("action.paste")

                    Button {
                        isInputFocused = false
                        Task {
                            await store.inspectCurrentInput()
                        }
                    } label: {
                        Label(store.isLoading ? "Inspecting" : "Inspect", systemImage: "shield.lefthalf.filled")
                            .font(.inspectRootSubheadlineSemibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.inspectAccent)
                    .disabled(store.isLoading)
                    .accessibilityIdentifier("action.inspect")
                }
            }
        }
    }

    private var pageHeader: some View {
        VStack(spacing: 6) {
            ZStack {
                Text("Inspect")
                    .font(.inspectRootTitle)
                    .frame(maxWidth: .infinity)

                if let closeAction {
                    HStack {
                        Spacer()
                        Button(action: closeAction) {
                            Image(systemName: "xmark")
                                .font(.inspectRootHeadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color.inspectChromeMutedFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("action.close")
                    }
                }
            }

            Text("TLS Certificate Inspector")
                .font(.inspectRootSubheadlineSemibold)
                .foregroundStyle(.primary.opacity(0.88))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var loadingCard: some View {
        InspectCard {
            HStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Handshaking")
                        .font(.inspectRootHeadline)
                    Text("Collecting the trust chain and negotiated protocol.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func summaryCard(_ report: TLSInspectionReport) -> some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(report.host)
                    .font(.inspectRootTitle3)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Badge(text: report.trust.badgeText, tint: report.trust.isTrusted ? .green : .orange)
                    Badge(text: protocolTitle(for: report.networkProtocolName), tint: .blue)
                    Badge(text: "\(report.certificates.count) cert\(report.certificates.count == 1 ? "" : "s")", tint: .indigo)
                    if report.security.criticalCount > 0 {
                        Badge(text: "\(report.security.criticalCount) critical", tint: .red)
                    } else if report.security.warningCount > 0 {
                        Badge(text: "\(report.security.warningCount) warning", tint: .orange)
                    }
                }

                if let leaf = report.leafCertificate {
                    LabeledContent("Issued To", value: leaf.subjectSummary)
                    LabeledContent("Issued By", value: leaf.issuerSummary)
                    LabeledContent("Validity", value: leaf.validity.status.rawValue)
                }

                if let failureReason = report.trust.failureReason, report.trust.isTrusted == false {
                    Text(failureReason)
                        .font(.inspectRootFootnote)
                        .foregroundStyle(.secondary)
                }

                if let sslLabsURL = report.sslLabsURL {
                    Link(destination: sslLabsURL) {
                        Label("Open in SSL Labs", systemImage: "arrow.up.right.square")
                    }
                    .font(.inspectRootSubheadlineSemibold)
                    .accessibilityIdentifier("action.open-ssllabs")
                }
            }
        }
    }

    private func securityCard(_ assessment: SecurityAssessment) -> some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Security Signals")
                        .font(.inspectRootHeadline)

                    if assessment.showsHeadline {
                        Spacer()
                        Text(assessment.headline)
                            .font(.inspectRootCaptionSemibold)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(assessment.findings) { finding in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(color(for: finding.severity))
                            .frame(width: 10, height: 10)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(finding.title)
                                .font(.inspectRootSubheadlineSemibold)
                            Text(finding.message)
                                .font(.inspectRootCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func chainCard(_ report: TLSInspectionReport) -> some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Certificate Chain")
                    .font(.inspectRootHeadline)

                ForEach(Array(report.certificates.enumerated()), id: \.element.id) { index, certificate in
                    NavigationLink {
                        CertificateDetailView(
                            report: report,
                            initialSelectionIndex: index
                        )
                    } label: {
                        CertificateRow(
                            certificate: certificate,
                            reportTrust: report.trust
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("chain.certificate.\(index)")
                }
            }
        }
    }

    private var recentCard: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recents")
                    .font(.inspectRootHeadline)

                ForEach(Array(store.recentInputs.enumerated()), id: \.offset) { index, recent in
                    let isCurrent = store.isCurrentTarget(recent)

                    Button {
                        isInputFocused = false
                        Task {
                            await store.inspectRecent(recent)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            RecentLookupIcon(host: recentHost(for: recent))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(recentPrimaryText(for: recent))
                                    .font(.inspectRootSubheadlineSemibold)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                if let secondaryText = recentSecondaryText(for: recent) {
                                    Text(secondaryText)
                                        .font(.inspectRootCaption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if isCurrent {
                                Text("Current")
                                    .font(.inspectRootCaptionSemibold)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("recent.\(index)")
                }
            }
        }
    }

    private var appLinksCard: some View {
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

    private func messageCard(title: String, message: String, tint: Color) -> some View {
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

    private func protocolTitle(for networkProtocolName: String?) -> String {
        switch networkProtocolName?.lowercased() {
        case "h2":
            return "HTTP/2"
        case "h3":
            return "HTTP/3"
        case "http/1.1":
            return "HTTP/1.1"
        case let value?:
            return value.uppercased()
        default:
            return "Protocol Unknown"
        }
    }

    private func color(for severity: SecurityFindingSeverity) -> Color {
        switch severity {
        case .good:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    private func recentHost(for recent: String) -> String? {
        (try? URLInputNormalizer.normalize(input: recent).host) ?? URL(string: recent)?.host
    }

    private func recentPrimaryText(for recent: String) -> String {
        guard let url = try? URLInputNormalizer.normalize(input: recent) else {
            return recent
        }

        return url.host ?? recent
    }

    private func recentSecondaryText(for recent: String) -> String? {
        guard let url = try? URLInputNormalizer.normalize(input: recent) else {
            return nil
        }

        let path = url.path == "/" ? "" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let tail = path + query
        return tail.isEmpty ? nil : tail
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

public enum InspectionPresentation: Sendable, Equatable {
    case app
    case actionExtension

    fileprivate var topPadding: CGFloat {
        self == .actionExtension ? 8 : 16
    }
}

private extension View {
    @ViewBuilder
    func inspectURLField() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .submitLabel(.go)
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyExtensionScrollMargins(_ presentation: InspectionPresentation) -> some View {
        #if os(iOS)
        if presentation == .actionExtension {
            self.contentMargins(.top, 0, for: .scrollContent)
        } else {
            self
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func hideRootNavigationBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func inlineRootNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func extensionGroupedListStyle() -> some View {
        #if os(iOS)
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
        #else
        self
            .listStyle(.automatic)
        #endif
    }
}

private struct InspectBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                .inspectBackgroundStart,
                .inspectBackgroundMiddle,
                .inspectBackgroundEnd
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.inspectGlow, Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .frame(width: 220, height: 220)
                .offset(x: 60, y: -40)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.inspectShapeTint, Color.clear],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 260, height: 220)
                .rotationEffect(.degrees(-18))
                .offset(x: -80, y: 80)
        }
    }
}

private struct InspectCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.inspectCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.inspectCardStroke, lineWidth: 1)
        )
        .shadow(color: .inspectCardShadow, radius: 10, y: 6)
    }
}

private struct Badge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.inspectRootCaptionSemibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.13), in: Capsule())
            .foregroundStyle(tint)
    }
}

private struct SmallFeatureGlyph: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(0.14))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: symbol)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(tint)
            }
    }
}

private struct RecentLookupIcon: View {
    let host: String?

    var body: some View {
        Group {
            if let faviconURL {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(7)
                            .frame(width: 38, height: 38)
                            .background(Color.inspectChromeMutedFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
    }

    private var faviconURL: URL? {
        guard let host, host.isEmpty == false else {
            return nil
        }

        return URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(host)")
    }

    private var fallback: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.blue.opacity(0.14))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: "globe")
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.blue)
            }
    }
}

private struct CertificateRow: View {
    let certificate: CertificateDetails
    let reportTrust: TrustSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(iconTint.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: iconName)
                        .foregroundStyle(iconTint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(certificate.subjectSummary)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(certificate.issuerSummary)
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.inspectRootCaptionBold)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.inspectChromeMutedFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.inspectCardStroke, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var iconName: String {
        if certificate.isLeaf, reportTrust.isTrusted == false {
            return "xmark.shield.fill"
        }
        if certificate.isLeaf {
            return "network.badge.shield.half.filled"
        }
        if certificate.isRoot {
            return "checkmark.shield.fill"
        }
        return "shield"
    }

    private var iconTint: Color {
        if certificate.isLeaf, reportTrust.isTrusted == false {
            return .red
        }
        if certificate.isLeaf {
            return .blue
        }
        if certificate.isRoot {
            return .green
        }
        return .indigo
    }
}

private enum AppLinks {
    static let appStore = URL(string: "https://apps.apple.com/us/app/inspect-view-tls-certificate/id1074957486")
    static let about = URL(string: "https://fourplexlabs.github.io/Inspect/about.html")
}

private extension Font {
    static let inspectRootTitle = Font.system(size: 29, weight: .bold, design: .rounded)
    static let inspectRootTitle3 = Font.system(size: 21, weight: .bold, design: .rounded)
    static let inspectRootHeadline = Font.system(size: 18, weight: .semibold)
    static let inspectRootSubheadline = Font.system(size: 16)
    static let inspectRootSubheadlineSemibold = Font.system(size: 16, weight: .semibold)
    static let inspectRootCaption = Font.system(size: 13)
    static let inspectRootCaptionSemibold = Font.system(size: 13, weight: .semibold)
    static let inspectRootCaptionBold = Font.system(size: 13, weight: .bold)
    static let inspectRootFootnote = Font.system(size: 14)
}
