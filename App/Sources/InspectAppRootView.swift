import InspectFeature
import SwiftUI

private enum InspectTab: Hashable {
    case inspect
    case monitor
    case logs
    case settings
}

struct InspectAppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: InspectTab = .inspect
    @State private var appProxyManager = AppProxyManager()

    var body: some View {
        if InspectionScreenshotScenario.current != nil {
            InspectionRootView(screenshotScenario: .current)
                .tint(.inspectAccent)
        } else {
            TabView(selection: $selectedTab) {
                InspectionRootView(
                    showsMonitorCard: false,
                    showsAboutCard: false
                )
                    .tabItem {
                        Label("Inspect", systemImage: "magnifyingglass.circle")
                    }
                    .tag(InspectTab.inspect)
                    .accessibilityIdentifier("tab.inspect")

                InspectionMonitorView {
                    await appProxyManager.refresh()
                }
                    .tabItem {
                        Label("Monitor", systemImage: "wave.3.right.circle")
                    }
                    .tag(InspectTab.monitor)
                    .accessibilityIdentifier("tab.monitor")

                InspectLogsView()
                    .tabItem {
                        Label("Logs", systemImage: "doc.text.magnifyingglass")
                    }
                    .tag(InspectTab.logs)
                    .accessibilityIdentifier("tab.logs")

                InspectSettingsView(manager: appProxyManager)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(InspectTab.settings)
                    .accessibilityIdentifier("tab.settings")
            }
            .tint(.inspectAccent)
            .task {
                let manager = appProxyManager
                InspectionLiveMonitorCoordinator.configure { isEnabled in
                    try await manager.setLiveMonitorEnabled(isEnabled)
                }
                await manager.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                Task {
                    await appProxyManager.refresh()
                }
            }
            .onDisappear {
                InspectionLiveMonitorCoordinator.configure(toggleHandler: nil)
            }
        }
    }
}
