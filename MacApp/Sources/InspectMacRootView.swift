import AppKit
import QuartzCore
import InspectFeature
import Observation
import SwiftUI

enum InspectMacSection: String, CaseIterable, Hashable, Identifiable {
    case inspect = "Inspect"
    case monitor = "Monitor"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .inspect:
            return "magnifyingglass.circle"
        case .monitor:
            return "wave.3.right.circle"
        case .settings:
            return "gearshape"
        }
    }
}

@MainActor
@Observable
final class InspectMacAppModel {
    var selectedSection: InspectMacSection? = .inspect
    var inspectSessionID = UUID()

    func startNewInspection() {
        selectedSection = .inspect
        inspectSessionID = UUID()
    }
}

struct InspectMacRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var appModel: InspectMacAppModel
    @Bindable var manager: InspectMacLiveMonitorManager
    let windowController: InspectMacWindowController

    var body: some View {
        NavigationSplitView {
            List(InspectMacSection.allCases, selection: $appModel.selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
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
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await manager.refresh()
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

            windowController.transition(to: preference)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appModel.selectedSection {
        case .inspect:
            InspectionRootView(
                showsMonitorCard: false,
                showsAboutCard: false
            )
            .id(appModel.inspectSessionID)
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

@MainActor
final class InspectMacWindowController {
    private weak var window: NSWindow?
    private var currentPreference: InspectionWindowLayoutPreference = .standard

    private let standardMinimumSize = NSSize(width: 1060, height: 740)
    private let standardTargetSize = NSSize(width: 1100, height: 760)
    private let detailMinimumSize = NSSize(width: 1360, height: 800)
    private let detailTargetSize = NSSize(width: 1420, height: 820)

    func attach(_ window: NSWindow) {
        self.window = window
        window.contentMinSize = standardMinimumSize
        currentPreference = .standard
        installDockIcon()
    }

    func transition(to preference: InspectionWindowLayoutPreference, animated: Bool = true) {
        guard let window else {
            return
        }

        let targetMinimumSize: NSSize
        let targetSize: NSSize
        switch preference {
        case .standard:
            targetMinimumSize = standardMinimumSize
            targetSize = standardTargetSize
        case .certificateDetail:
            targetMinimumSize = detailMinimumSize
            targetSize = detailTargetSize
        }

        let previousPreference = currentPreference
        currentPreference = preference
        window.contentMinSize = targetMinimumSize

        var frame = window.frame
        let targetWidth: CGFloat
        let targetHeight: CGFloat

        switch preference {
        case .standard:
            targetWidth = frame.width > targetSize.width ? targetSize.width : max(frame.width, targetMinimumSize.width)
            targetHeight = frame.height > targetSize.height ? targetSize.height : max(frame.height, targetMinimumSize.height)
        case .certificateDetail:
            targetWidth = max(frame.width, targetSize.width)
            targetHeight = max(frame.height, targetSize.height)
        }

        guard previousPreference != preference || frame.width != targetWidth || frame.height != targetHeight else {
            return
        }

        let heightDelta = targetHeight - frame.height
        frame.size.width = targetWidth
        frame.size.height = targetHeight
        frame.origin.y -= heightDelta

        guard animated else {
            window.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }
    }

    private func installDockIcon() {
        guard let iconURL = Bundle.main.url(forResource: "Inspect", withExtension: "icns"),
              let iconImage = NSImage(contentsOf: iconURL) else {
            return
        }

        NSApp.applicationIconImage = iconImage
    }
}

struct InspectMacWindowReader: NSViewRepresentable {
    let onResolve: @MainActor (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
