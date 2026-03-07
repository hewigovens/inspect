import InspectCore
import SwiftUI

@MainActor
public struct InspectionDiagnosticsView: View {
    @State private var monitorStore = InspectionMonitorSharedStore.shared
    @State private var logText = InspectionTunnelLogCard.emptyStateText
    @State private var autoRefresh = true

    public init() {}

    public var body: some View {
        InspectionDiagnosticsContainer(title: "Diagnostics") {
            InspectionEventsCard(store: monitorStore)
            InspectionTunnelLogCard(
                logText: $logText,
                autoRefresh: $autoRefresh
            )
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
    @State private var logText = InspectionTunnelLogCard.emptyStateText
    @State private var autoRefresh = true

    public init() {}

    public var body: some View {
        InspectionDiagnosticsContainer(title: "Tunnel Log") {
            InspectionTunnelLogCard(
                logText: $logText,
                autoRefresh: $autoRefresh
            )
        }
    }
}

private struct InspectionDiagnosticsContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            InspectBackground()
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 18) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

@MainActor
private struct InspectionEventsCard: View {
    @Bindable var store: InspectionMonitorStore

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Events")
                            .font(.inspectRootHeadline)

                        Text("Low-level monitor history captured from live traffic.")
                            .font(.inspectRootCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(store.entries.count)")
                        .font(.inspectRootCaptionSemibold)
                        .foregroundStyle(.secondary)
                }

                if store.entries.isEmpty {
                    Text("No monitor events yet.")
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(store.entries) { entry in
                            MonitorEntryRow(entry: entry)
                        }
                    }
                }

                Button("Clear Event History") {
                    store.clear()
                }
                .font(.inspectRootCaptionSemibold)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
private struct InspectionTunnelLogCard: View {
    static let emptyStateText = "No tunnel log yet. Start Live Monitor to generate logs."

    @Binding var logText: String
    @Binding var autoRefresh: Bool
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tunnel Log")
                            .font(.inspectRootHeadline)

                        Text("Extension and forwarding-engine diagnostics from the shared app group log.")
                            .font(.inspectRootCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle(isOn: $autoRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .toggleStyle(.button)
                }

                Text(logText)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.inspectChromeFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .textSelection(.enabled)

                HStack(spacing: 14) {
                    Button("Copy Log") {
                        InspectClipboard.copy(logText)
                    }
                    .font(.inspectRootCaptionSemibold)
                    .buttonStyle(.plain)

                    Button("Clear Log") {
                        clearLog()
                    }
                    .font(.inspectRootCaptionSemibold)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            loadLog()
        }
        .onReceive(timer) { _ in
            guard autoRefresh else {
                return
            }

            loadLog()
        }
    }

    private func loadLog() {
        DispatchQueue.global(qos: .utility).async {
            let text = InspectSharedLog.readTail()
            DispatchQueue.main.async {
                logText = text ?? Self.emptyStateText
            }
        }
    }

    private func clearLog() {
        DispatchQueue.global(qos: .utility).async {
            InspectSharedLog.reset()
            DispatchQueue.main.async {
                logText = "Tunnel log cleared."
            }
        }
    }
}
