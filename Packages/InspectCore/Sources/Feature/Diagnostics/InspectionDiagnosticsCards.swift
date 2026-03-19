import SwiftUI

@MainActor
struct InspectionEventsCard: View {
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
            }
        }
    }
}

@MainActor
struct InspectionTunnelLogCard: View {
    @Bindable var store: InspectionTunnelLogStore
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        InspectCard {
            InspectionTunnelLogContent(store: store, showsHeader: true)
        }
        .task {
            store.refresh()
        }
        .onReceive(timer) { _ in
            guard store.autoRefresh else {
                return
            }

            store.refresh()
        }
    }
}

@MainActor
struct InspectionTunnelLogContent: View {
    @Bindable var store: InspectionTunnelLogStore
    let showsHeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tunnel Log")
                            .font(.inspectRootHeadline)

                        Text("Extension and forwarding-engine diagnostics from the shared app group log.")
                            .font(.inspectRootCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            Text(store.text)
                .font(.system(.caption2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.inspectChromeFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.inspectCardStroke, lineWidth: 1)
                )
                .contextMenu {
                    Button {
                        store.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button {
                        store.copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    ShareLink(
                        item: store.text,
                        subject: Text("Inspect Tunnel Log"),
                        message: Text("Shared from Inspect")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.canShare == false)

                    Button(role: .destructive) {
                        store.clear()
                    } label: {
                        Label("Reset", systemImage: "trash")
                    }
                }
        }
    }
}
