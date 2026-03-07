import InspectCore
import SwiftUI

@MainActor
public struct InspectionDiagnosticsView: View {
    @State private var monitorStore = InspectionMonitorSharedStore.shared
    @State private var logStore = InspectionDiagnosticsSharedState.tunnelLogStore

    public init() {}

    public var body: some View {
        InspectionDiagnosticsContainer(title: "Diagnostics") {
            InspectionEventsCard(store: monitorStore)
            InspectionTunnelLogCard(store: logStore)
        }
    }
}

@MainActor
public struct InspectionEventsView: View {
    @State private var monitorStore = InspectionMonitorSharedStore.shared

    public init() {}

    public var body: some View {
        InspectionDiagnosticsContainer(title: "Events") {
            InspectionEventsCard(store: monitorStore)
        }
    }
}

@MainActor
public struct InspectionTunnelLogView: View {
    @State private var logStore = InspectionDiagnosticsSharedState.tunnelLogStore

    public init() {}

    public var body: some View {
        InspectionDiagnosticsContainer(title: "Tunnel Log") {
            InspectionTunnelLogCard(store: logStore)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    logStore.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityIdentifier("diagnostics.log.refresh")

                ShareLink(
                    item: logStore.text,
                    subject: Text("Inspect Tunnel Log"),
                    message: Text("Shared from Inspect")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(logStore.canShare == false)
                .accessibilityIdentifier("diagnostics.log.share")

                Button(role: .destructive) {
                    logStore.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityIdentifier("diagnostics.log.reset")
            }
        }
    }
}

@MainActor
private enum InspectionDiagnosticsSharedState {
    static let tunnelLogStore = InspectionTunnelLogStore()
}
