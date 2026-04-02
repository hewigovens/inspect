import InspectKit
import SwiftUI

struct InspectAppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: InspectSection = .inspect
    @State private var liveMonitorManager = LiveMonitorManager()
    @State private var isLiveMonitorCoordinatorReady = false
    @State private var deferredAppRoute: InspectAppRoute?

    var body: some View {
        if let screenshotScenario = InspectionScreenshotScenario.current {
            InspectionAppStoreScreenshotView(scenario: screenshotScenario)
                .tint(.inspectAccent)
        } else {
            TabView(selection: $selectedTab) {
                InspectionRootView(
                    showsMonitorCard: false,
                    showsAboutCard: false
                )
                .tabItem {
                    Label(InspectSection.inspect.title, systemImage: InspectSection.inspect.systemImage)
                }
                .tag(InspectSection.inspect)
                .accessibilityIdentifier("tab.inspect")

                InspectionMonitorView {
                    await liveMonitorManager.refresh()
                }
                .tabItem {
                    Label(InspectSection.monitor.title, systemImage: InspectSection.monitor.systemImage)
                }
                .tag(InspectSection.monitor)
                .accessibilityIdentifier("tab.monitor")

                InspectSettingsView(manager: liveMonitorManager)
                    .tabItem {
                        Label(InspectSection.settings.title, systemImage: InspectSection.settings.systemImage)
                    }
                    .tag(InspectSection.settings)
                    .accessibilityIdentifier("tab.settings")
            }
            .tint(.inspectAccent)
            .onReceive(NotificationCenter.default.publisher(for: InspectionExternalInputCenter.notification)) { _ in
                selectedTab = .inspect
            }
            .onReceive(NotificationCenter.default.publisher(for: InspectAppRouteCenter.notification)) { _ in
                guard let route = InspectAppRouteCenter.consumePendingRoute() else {
                    return
                }

                if shouldDefer(route) {
                    deferredAppRoute = route
                } else {
                    handleAppRoute(route)
                }
            }
            .task {
                let manager = liveMonitorManager
                InspectionLiveMonitorCoordinator.configure { isEnabled in
                    try await manager.setLiveMonitorEnabled(isEnabled)
                }
                isLiveMonitorCoordinatorReady = true
                await manager.refresh()

                if let route = deferredAppRoute ?? InspectAppRouteCenter.consumePendingRoute() {
                    deferredAppRoute = nil
                    handleAppRoute(route)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                Task {
                    await liveMonitorManager.refresh()
                }
            }
            .onDisappear {
                isLiveMonitorCoordinatorReady = false
                deferredAppRoute = nil
                InspectionLiveMonitorCoordinator.configure(toggleHandler: nil)
            }
        }
    }

    private func shouldDefer(_ route: InspectAppRoute) -> Bool {
        if case .toggleLiveMonitor = route {
            return isLiveMonitorCoordinatorReady == false
        }

        return false
    }

    private func handleAppRoute(_ route: InspectAppRoute) {
        switch route {
        case let .section(section):
            selectedTab = section
        case .toggleLiveMonitor:
            selectedTab = .monitor
            let targetEnabled = InspectionLiveMonitorPreferenceStore.isEnabled == false
            Task {
                try? await liveMonitorManager.setLiveMonitorEnabled(targetEnabled)
                await liveMonitorManager.refresh()
            }
        }
    }
}
