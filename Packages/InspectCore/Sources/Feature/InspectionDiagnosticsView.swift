import InspectCore
import SwiftUI

@MainActor
public struct InspectionDiagnosticsView: View {
    @State private var monitorStore = InspectionMonitorSharedStore.shared
    @State private var logText = "No tunnel log yet. Start Live Monitor to generate logs."
    @State private var autoRefresh = true
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        ZStack {
            InspectBackground()
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 18) {
                    eventsCard
                    logCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
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

    private var eventsCard: some View {
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

                    Text("\(monitorStore.entries.count)")
                        .font(.inspectRootCaptionSemibold)
                        .foregroundStyle(.secondary)
                }

                if monitorStore.entries.isEmpty {
                    Text("No monitor events yet.")
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(monitorStore.entries) { entry in
                            MonitorEntryRow(entry: entry)
                        }
                    }
                }

                Button("Clear Event History") {
                    monitorStore.clear()
                }
                .font(.inspectRootCaptionSemibold)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var logCard: some View {
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
    }

    private func loadLog() {
        DispatchQueue.global(qos: .utility).async {
            let text = InspectSharedLog.readTail()
            DispatchQueue.main.async {
                logText = text ?? "No tunnel log yet. Start Live Monitor to generate logs."
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
