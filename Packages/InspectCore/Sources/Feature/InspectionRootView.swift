import Observation
import SwiftUI

@MainActor
public struct InspectionRootView: View {
    @AppStorage("inspect.dismiss-demo-target") private var dismissDemoTarget = false
    @FocusState private var isInputFocused: Bool
    @State private var store = InspectionStore()
    @State private var monitorStore: InspectionMonitorStore

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
        .task(id: bootstrapURL?.absoluteString) {
            store.bootstrap(initialURL: bootstrapURL)
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
                        ToolbarItem(placement: .topBarLeading) {
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
                .hideRootNavigationBar()
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
                LazyVStack(spacing: 18) {
                    InspectionPageHeader(closeAction: closeAction)
                        .id("header")

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
                        isInputFocused: $isInputFocused
                    )

                    if showsAboutCard, screenshotScenario?.showsAboutCard != false {
                        InspectionAppLinksCard(appVersionText: InspectionAppMetadata.versionText)
                            .id("about")
                    }
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
            if let screenshotScenario {
                dismissDemoTarget = screenshotScenario.showsDemoTargets == false
            }
        }
    }

    private var bootstrapURL: URL? {
        screenshotScenario?.initialURL ?? initialURL
    }
}
