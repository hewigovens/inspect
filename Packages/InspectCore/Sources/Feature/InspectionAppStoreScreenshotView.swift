import SwiftUI

private enum InspectionScreenshotTab: Hashable {
    case inspect
    case monitor
    case settings
}

@MainActor
public struct InspectionAppStoreScreenshotView: View {
    private let scenario: InspectionScreenshotScenario
    @State private var selectedTab: InspectionScreenshotTab
    @State private var monitorStore: InspectionMonitorStore

    public init(scenario: InspectionScreenshotScenario) {
        self.scenario = scenario
        _selectedTab = State(initialValue: scenario.prefersMonitorTab ? .monitor : .inspect)
        _monitorStore = State(initialValue: InspectionScreenshotFixtures.makeMonitorStore())
    }

    public var body: some View {
        #if os(macOS)
        macShell
        #else
        switch scenario {
        case .inspectTab, .monitorTab:
            tabShell
        case .hostDetail:
            if let host = featuredHost {
                NavigationStack {
                    InspectionMonitorHostDetailView(store: monitorStore, host: host)
                }
                .tint(.inspectAccent)
            }
        case .certificateChain:
            NavigationStack {
                CertificateDetailView(report: InspectionScreenshotFixtures.featuredReport, initialSelectionIndex: 0)
            }
            .tint(.inspectAccent)
        }
        #endif
    }

    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            InspectionRootView(
                screenshotScenario: .inspectTab,
                showsMonitorCard: false,
                showsAboutCard: false
            )
                .tabItem {
                    Label("Inspect", systemImage: "magnifyingglass.circle")
                }
                .tag(InspectionScreenshotTab.inspect)

            InspectionMonitorView(monitorStore: monitorStore)
                .tabItem {
                    Label("Monitor", systemImage: "wave.3.right.circle")
                }
                .tag(InspectionScreenshotTab.monitor)

            screenshotPlaceholder(title: "Settings")
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(InspectionScreenshotTab.settings)
        }
        .tint(.inspectAccent)
    }

    #if os(macOS)
    private var macShell: some View {
        NavigationSplitView {
            List(selection: .constant(selectedSidebarTab)) {
                Label("Inspect", systemImage: "magnifyingglass.circle")
                    .tag(InspectionScreenshotTab.inspect)
                Label("Monitor", systemImage: "wave.3.right.circle")
                    .tag(InspectionScreenshotTab.monitor)
                Label("Settings", systemImage: "gearshape")
                    .tag(InspectionScreenshotTab.settings)
            }
            .navigationSplitViewColumnWidth(min: 164, ideal: 188, max: 220)
        } detail: {
            macDetail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1280, minHeight: 800)
        .tint(.inspectAccent)
    }

    @ViewBuilder
    private var macDetail: some View {
        switch scenario {
        case .inspectTab:
            InspectionRootView(
                screenshotScenario: .inspectTab,
                showsMonitorCard: false,
                showsAboutCard: false
            )
        case .monitorTab:
            InspectionMonitorView(monitorStore: monitorStore)
        case .hostDetail:
            if let host = featuredHost {
                NavigationStack {
                    InspectionMonitorHostDetailView(store: monitorStore, host: host)
                }
            } else {
                screenshotPlaceholder(title: "Monitor")
            }
        case .certificateChain:
            NavigationStack {
                CertificateDetailView(report: InspectionScreenshotFixtures.featuredReport, initialSelectionIndex: 0)
            }
        }
    }

    private var selectedSidebarTab: InspectionScreenshotTab {
        switch scenario {
        case .inspectTab, .certificateChain:
            return .inspect
        case .monitorTab, .hostDetail:
            return .monitor
        }
    }
    #endif

    private var featuredHost: InspectionMonitoredHost? {
        monitorStore.monitoredHosts.first
    }

    private func screenshotPlaceholder(title: String) -> some View {
        ZStack {
            InspectBackground()
                .ignoresSafeArea()

            Text(title)
                .font(.inspectRootHeadline)
                .foregroundStyle(.secondary)
        }
    }
}

private extension InspectionScreenshotScenario {
    var prefersMonitorTab: Bool {
        switch self {
        case .monitorTab, .hostDetail, .certificateChain:
            return true
        case .inspectTab:
            return false
        }
    }
}
