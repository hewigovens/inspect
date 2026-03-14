import InspectCore
import InspectFeature
import SwiftUI

struct InspectMacRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var appModel: InspectMacAppModel
    @Bindable var manager: InspectMacLiveMonitorManager
    let windowController: InspectMacWindowController
    private let logger = InspectRuntimeLogger(
        category: "InspectMacRootView",
        scope: "MacShareHandoff"
    )

    var body: some View {
        NavigationSplitView {
            List(InspectSection.allCases, selection: $appModel.selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 164, ideal: 188, max: 220)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1060, minHeight: 740)
        .background {
            InspectMacWindowReader { window in
                windowController.attach(window)
            }
        }
        .tint(.inspectAccent)
        .task {
            InspectionLiveMonitorCoordinator.configure { isEnabled in
                try await manager.setLiveMonitorEnabled(isEnabled)
            }
            await manager.refresh()
            consumePendingSharedInputIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await manager.refresh()
            }
            consumePendingSharedInputIfNeeded()
        }
        .onChange(of: appModel.selectedSection) { _, _ in
            windowController.transition(to: .standard)
        }
        .onDisappear {
            InspectionLiveMonitorCoordinator.configure(toggleHandler: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: InspectionWindowLayoutCenter.notification)) { notification in
            guard let preference = InspectionWindowLayoutCenter.preference(from: notification) else {
                return
            }

            windowController.transition(to: preference)
        }
        .onReceive(NotificationCenter.default.publisher(for: InspectionExternalInputCenter.notification)) { _ in
            appModel.startNewInspection()
            windowController.transition(to: .standard)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let inspectSessionID = appModel.inspectSessionID

        switch appModel.selectedSection {
        case .inspect:
            InspectionRootView(
                showsMonitorCard: false,
                showsAboutCard: false
            )
            .id(inspectSessionID)
        case .monitor:
            InspectionMonitorView {
                await manager.refresh()
            }
        case .settings:
            InspectMacSettingsView(manager: manager)
        case nil:
            ContentUnavailableView(
                "Select a Section",
                systemImage: "sidebar.left",
                description: Text("Choose Inspect, Monitor, or Settings from the sidebar.")
            )
        }
    }

    private func consumePendingSharedInputIfNeeded() {
        guard let input = InspectionSharedInputStore.consumeNextPending() else {
            return
        }

        logger.critical("mac app consumed queued share input: \(input)")
        appModel.startNewInspection()
        windowController.transition(to: .standard)
        InspectionExternalInputCenter.submitInput(input)
    }

}
