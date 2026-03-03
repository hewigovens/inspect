import Observation
import SwiftUI

public struct InspectionRootView: View {
    @AppStorage("inspect.dismiss-demo-target") private var dismissDemoTarget = false
    @FocusState private var isInputFocused: Bool
    @State private var store = InspectionStore()

    private let initialURL: URL?
    private let closeAction: (() -> Void)?
    private let presentation: InspectionPresentation
    private let screenshotScenario: InspectionScreenshotScenario?

    public init(
        initialURL: URL? = nil,
        closeAction: (() -> Void)? = nil,
        presentation: InspectionPresentation = .app,
        screenshotScenario: InspectionScreenshotScenario? = nil
    ) {
        self.initialURL = initialURL
        self.closeAction = closeAction
        self.presentation = presentation
        self.screenshotScenario = screenshotScenario
    }

    public var body: some View {
        NavigationStack {
            content
        }
        .tint(.inspectAccent)
        .task(id: bootstrapURL?.absoluteString) {
            store.bootstrap(initialURL: bootstrapURL)
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

                    if screenshotScenario?.showsAboutCard != false {
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
