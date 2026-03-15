import InspectKit
import SwiftUI

struct InspectAppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: InspectSection = .inspect
    @State private var liveMonitorManager = LiveMonitorManager()

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
            .task {
                let manager = liveMonitorManager
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
                    await liveMonitorManager.refresh()
                }
            }
            .onDisappear {
                InspectionLiveMonitorCoordinator.configure(toggleHandler: nil)
            }
        }
    }
}
