import SwiftUI

@MainActor
enum InspectionMonitorSharedStore {
    static let shared = InspectionMonitorStore(enableNetworkFeedPolling: true)
}

@MainActor
public struct InspectionMonitorView: View {
    @State private var monitorStore: InspectionMonitorStore
    @State private var isRefreshing = false
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
                .navigationBarTitleDisplayMode(.inline)
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

                    InspectionMonitorHostListCard(store: monitorStore)
                        .id("monitor.hosts")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
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
