import InspectCore
import Observation
import SwiftUI

@MainActor
public struct InspectionRootView: View {
    @AppStorage("inspect.dismiss-demo-target") private var dismissDemoTarget = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isInputFocused: Bool
    @State private var store = InspectionStore()
    @State private var monitorStore: InspectionMonitorStore
    @State private var certificateRoute: InspectionCertificateRoute?

    private let initialURL: URL?
    private let closeAction: (() -> Void)?
    private let presentation: InspectionPresentation
    private let screenshotScenario: InspectionScreenshotScenario?
    private let showsMonitorCard: Bool
    private let showsAboutCard: Bool

    public init(
        initialURL: URL? = nil,
        closeAction: (() -> Void)? = nil,
        presentation: InspectionPresentation = .app,
        screenshotScenario: InspectionScreenshotScenario? = nil,
        showsMonitorCard: Bool = true,
        showsAboutCard: Bool = true
    ) {
        self.initialURL = initialURL
        self.closeAction = closeAction
        self.presentation = presentation
        self.screenshotScenario = screenshotScenario
        self.showsMonitorCard = showsMonitorCard
        self.showsAboutCard = showsAboutCard

        let monitorStore: InspectionMonitorStore
        if presentation == .app, screenshotScenario == nil {
            monitorStore = InspectionMonitorSharedStore.shared
        } else {
            monitorStore = InspectionMonitorStore(
                enableNetworkFeedPolling: presentation == .app && screenshotScenario == nil
            )
        }
        _monitorStore = State(initialValue: monitorStore)
    }

    public var body: some View {
        NavigationStack {
            content
        }
        .tint(.inspectAccent)
        .task(id: bootstrapTaskKey) {
            let pendingRequest = presentation == .app
                ? InspectionExternalInputCenter.consumePendingRequest()
                : nil

            store.bootstrap(initialURL: bootstrapURL)

            if let pendingRequest {
                handleExternalRequest(pendingRequest)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: InspectionExternalInputCenter.notification)) { _ in
            guard presentation == .app,
                  let request = InspectionExternalInputCenter.consumePendingRequest() else {
                return
            }

            handleExternalRequest(request)
        }
        .onChange(of: store.report?.id) { _, _ in
            guard screenshotScenario == nil, let report = store.report else {
                return
            }

            monitorStore.recordInspection(report)
        }
    }

    @ViewBuilder
    private var content: some View {
        if presentation == .app, screenshotScenario?.showsCertificateDetail == true, let report = store.report {
            CertificateDetailView(report: report, initialSelectionIndex: 0)
                .ensureNavigationBarVisible()
        } else if presentation == .actionExtension, let report = store.report {
            CertificateDetailView(report: report, initialSelectionIndex: 0)
                .toolbar {
                    if let closeAction {
                        ToolbarItem(placement: InspectPlatform.topBarLeadingPlacement) {
                            Button("Done", action: closeAction)
                        }
                    }
                }
        } else if presentation == .actionExtension, initialURL != nil {
            ExtensionInspectionContent(
                store: store,
                initialURL: initialURL,
                closeAction: closeAction
            )
        } else {
            rootContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .navigationTitle("Inspect")
                .inlineRootNavigationTitle()
        }
    }

    private var rootContent: some View {
        let report = store.report
        let recentItems = screenshotScenario?.showsRecents == false
            ? []
            : store.recentInputs.map(RecentLookupItem.init)

        return ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            InspectBackground()
                .ignoresSafeArea()

            ScrollView {
                Group {
                    if usesRegularDashboardLayout {
                        regularWidthContent(report: report, recentItems: recentItems)
                    } else {
                        compactWidthContent(report: report, recentItems: recentItems)
                    }
                }
                .frame(maxWidth: rootContentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, rootHorizontalPadding)
                .padding(.top, presentation.topPadding)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollBounceBehavior(.basedOnSize)
            .inspectScrollDismissesKeyboard()
            .applyExtensionScrollMargins(presentation)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            isInputFocused = false
            if let screenshotScenario {
                dismissDemoTarget = screenshotScenario.showsDemoTargets == false
            }
        }
        .navigationDestination(item: $certificateRoute) { route in
            CertificateDetailView(
                report: route.report,
                initialSelectionIndex: route.initialSelectionIndex
            )
        }
    }

    private func compactWidthContent(report: TLSInspectionReport?, recentItems: [RecentLookupItem]) -> some View {
        LazyVStack(spacing: rootStackSpacing) {
            InspectionInputCard(
                store: store,
                dismissDemoTarget: $dismissDemoTarget,
                isInputFocused: $isInputFocused
            )
            .id("input")

            if presentation == .app,
               showsMonitorCard,
               screenshotScenario?.showsMonitorCard != false {
                InspectionMonitorCard(store: monitorStore)
                    .id("monitor")
            }

            InspectionResultsContent(
                isLoading: store.isLoading,
                errorMessage: store.errorMessage,
                report: report,
                recentItems: recentItems,
                currentReportURL: report?.requestedURL,
                onInspectRecent: { recentInput in
                    await store.inspectRecent(recentInput)
                },
                onClearRecents: {
                    store.clearRecents()
                },
                onOpenCertificateDetail: openCertificateDetail,
                isInputFocused: $isInputFocused
            )

            if showsAboutCard, screenshotScenario?.showsAboutCard != false {
                InspectionAppLinksCard(appVersionText: InspectionAppMetadata.versionText)
                    .id("about")
            }
        }
    }

    private func regularWidthContent(report: TLSInspectionReport?, recentItems: [RecentLookupItem]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            InspectionInputCard(
                store: store,
                dismissDemoTarget: $dismissDemoTarget,
                isInputFocused: $isInputFocused
            )
            .id("input")

            HStack(alignment: .top, spacing: 18) {
                regularMainColumn(report: report)
                    .frame(maxWidth: .infinity, alignment: .top)

                regularSideRail(report: report, recentItems: recentItems)
                    .frame(width: regularSideRailWidth, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func regularMainColumn(report: TLSInspectionReport?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.isLoading {
                InspectionLoadingCard()
                    .id("loading")
            }

            if let errorMessage = store.errorMessage {
                InspectionMessageCard(
                    title: "Inspection Failed",
                    message: errorMessage,
                    tint: .orange
                )
                .id("error")
            }

            if let report {
                InspectionSummaryCard(report: report)
                    .id("summary")
                InspectionSecurityCard(assessment: report.security)
                    .id("security")
            } else {
                InspectionWorkspaceCard()
                    .id("workspace")
            }
        }
    }

    @ViewBuilder
    private func regularSideRail(report: TLSInspectionReport?, recentItems: [RecentLookupItem]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let report {
                InspectionChainCard(
                    report: report,
                    onOpenCertificateDetail: openCertificateDetail
                )
                .id("chain")
            }

            if recentItems.isEmpty {
                InspectionRecentPlaceholderCard()
                    .id("recents-empty")
            } else {
                InspectionRecentCard(
                    items: recentItems,
                    currentReportURL: report?.requestedURL,
                    onInspectRecent: { recentInput in
                        await store.inspectRecent(recentInput)
                    },
                    onClearRecents: {
                        store.clearRecents()
                    },
                    isInputFocused: $isInputFocused
                )
                .id("recents")
            }

            if presentation == .app,
               showsMonitorCard,
               screenshotScenario?.showsMonitorCard != false {
                InspectionMonitorCard(store: monitorStore)
                    .id("monitor")
            }

            if showsAboutCard, screenshotScenario?.showsAboutCard != false {
                InspectionAppLinksCard(appVersionText: InspectionAppMetadata.versionText)
                    .id("about")
            }
        }
    }

    private var bootstrapURL: URL? {
        screenshotScenario?.initialURL ?? initialURL
    }

    private var bootstrapTaskKey: String {
        bootstrapURL?.absoluteString ?? "inspect-root-bootstrap"
    }

    private var rootContentMaxWidth: CGFloat? {
        InspectLayout.Root.contentMaxWidth(usesRegularDashboardLayout: usesRegularDashboardLayout)
    }

    private var rootHorizontalPadding: CGFloat {
        InspectLayout.Root.horizontalPadding(usesRegularDashboardLayout: usesRegularDashboardLayout)
    }

    private var rootStackSpacing: CGFloat {
        InspectLayout.Root.stackSpacing
    }

    private var regularSideRailWidth: CGFloat {
        InspectLayout.Root.sideRailWidth
    }

    private var usesRegularDashboardLayout: Bool {
        InspectLayout.Root.usesRegularDashboardLayout(
            presentation: presentation,
            horizontalSizeClass: horizontalSizeClass
        )
    }

    private func openCertificateDetail(_ report: TLSInspectionReport, _ index: Int) {
        certificateRoute = InspectionCertificateRoute(
            report: report,
            initialSelectionIndex: index
        )
    }

    private func handleExternalRequest(_ request: InspectionExternalRequest) {
        store.applyExternalRequest(request)

        switch request {
        case let .report(report, opensCertificateDetail):
            guard opensCertificateDetail else {
                certificateRoute = nil
                return
            }

            certificateRoute = InspectionCertificateRoute(
                report: report,
                initialSelectionIndex: 0
            )
        }
    }
}
