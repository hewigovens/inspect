import SwiftUI

@MainActor
enum InspectionMonitorSharedStore {
    static let shared = InspectionMonitorStore(enableNetworkFeedPolling: true)
}

@MainActor
public struct InspectionMonitorView: View {
    @State private var monitorStore: InspectionMonitorStore
    @State private var isRefreshing = false
    @State private var hostSearchText = ""
    @State private var hostFilter: InspectionMonitorHostFilter = .all
    @State private var isHostSearchExpanded = false
    @FocusState private var isHostSearchFocused: Bool
    private let refreshAction: (@MainActor () async -> Void)?

    public init(refreshAction: (@MainActor () async -> Void)? = nil) {
        _monitorStore = State(initialValue: InspectionMonitorSharedStore.shared)
        self.refreshAction = refreshAction
    }

    init(
        monitorStore: InspectionMonitorStore,
        refreshAction: (@MainActor () async -> Void)? = nil
    ) {
        _monitorStore = State(initialValue: monitorStore)
        self.refreshAction = refreshAction
    }

    public var body: some View {
        NavigationStack {
            monitorContent
                .navigationTitle("Monitor")
                .inlineRootNavigationTitle()
        }
        .onChange(of: isHostSearchFocused) { _, isFocused in
            if isFocused == false && hostSearchText.isEmpty {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isHostSearchExpanded = false
                }
            }
        }
        .onAppear {
            Task {
                await runRefresh(showLoading: false)
            }
        }
        .tint(.inspectAccent)
    }

    private var monitorContent: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            InspectBackground()
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 18) {
                    InspectionMonitorCard(
                        store: monitorStore,
                        isRefreshing: isRefreshing,
                        refreshAction: cardRefreshAction
                    )
                    .id("monitor")

                    InspectionMonitorHostListCard(
                        store: monitorStore,
                        searchText: $hostSearchText,
                        filter: $hostFilter,
                        isSearchExpanded: $isHostSearchExpanded,
                        isSearchFocused: $isHostSearchFocused
                    )
                    .id("monitor.hosts")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, InspectLayout.Monitor.scrollBottomContentPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var cardRefreshAction: (() -> Void)? {
        guard refreshAction != nil else {
            return nil
        }

        return {
            Task {
                await runRefresh()
            }
        }
    }

    private func runRefresh(showLoading: Bool = true) async {
        guard let refreshAction else {
            return
        }
        guard isRefreshing == false else {
            return
        }

        if showLoading {
            isRefreshing = true
        }
        await refreshAction()
        if showLoading {
            isRefreshing = false
        }
    }
}
