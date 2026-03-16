import AppKit
import InspectKit
import SwiftUI

struct InspectMacRootView: View {
    @Bindable var appModel: InspectMacAppModel
    @Bindable var manager: InspectMacLiveMonitorManager
    @State private var isHandlingActivation = false
    let windowController: InspectMacWindowController

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
        .frame(minWidth: 960, minHeight: 740)
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
            await handleAppActivation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await handleAppActivation()
            }
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

            if preference == .certificateDetail, appModel.selectedSection == .inspect {
                windowController.reveal()
            }

            windowController.transition(to: preference)
        }
        .onReceive(NotificationCenter.default.publisher(for: InspectionExternalInputCenter.notification)) { _ in
            appModel.selectedSection = .inspect
            windowController.reveal()
            windowController.transition(to: .standard)
        }
    }

    private func consumePendingSharedReportIfNeeded() {
        guard let request = InspectionExternalInputCenter.consumePendingSharedReportRequest() else {
            return
        }

        appModel.startNewInspection()
        appModel.selectedSection = .inspect
        windowController.reveal()
        windowController.transition(to: .standard, animated: false)

        DispatchQueue.main.async {
            InspectionExternalInputCenter.submit(request)
        }
    }

    private func handleAppActivation() async {
        guard isHandlingActivation == false else {
            return
        }

        isHandlingActivation = true
        defer { isHandlingActivation = false }

        await manager.refresh()
        consumePendingSharedReportIfNeeded()
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
}
