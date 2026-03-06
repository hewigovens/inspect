import SwiftUI

struct InspectionMonitorCard: View {
    @Bindable var store: InspectionMonitorStore
    let isRefreshing: Bool
    let refreshAction: (() -> Void)?

    init(
        store: InspectionMonitorStore,
        isRefreshing: Bool = false,
        refreshAction: (() -> Void)? = nil
    ) {
        self._store = Bindable(store)
        self.isRefreshing = isRefreshing
        self.refreshAction = refreshAction
    }

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                header

                if let message = store.liveMonitorMessage {
                    Text(message)
                        .font(.inspectRootCaption)
                        .foregroundStyle(.red)
                }

                if store.isEnabled {
                    enabledContent
                } else {
                    Text("Enable Live Monitor to track observed hosts and probe their certificates.")
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Monitor")
                    .font(.inspectRootHeadline)
                Text("Track discovered hosts and certificate changes.")
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { store.isEnabled },
                set: { store.setEnabled($0) }
            ))
            .labelsHidden()
            .disabled(store.isApplyingLiveMonitorToggle)
            .accessibilityIdentifier("monitor.toggle")
        }
    }

    @ViewBuilder
    private var enabledContent: some View {
        if let refreshAction {
            Button {
                refreshAction()
            } label: {
                HStack(spacing: 8) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Refresh")
                }
                .font(.inspectRootCaptionSemibold)
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
            .accessibilityIdentifier("monitor.refresh")
        }

        NavigationLink {
            InspectionMonitorHostsView(store: store)
        } label: {
            HStack(spacing: 10) {
                Text("\(store.monitoredHosts.count) host\(store.monitoredHosts.count == 1 ? "" : "s") found")
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.inspectRootCaptionBold)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("monitor.hosts-link")

        if store.entries.isEmpty {
            Text("No monitor events yet. Browse websites to populate the feed.")
                .font(.inspectRootCaption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.entries.prefix(6)) { entry in
                    MonitorEntryRow(entry: entry)
                }

                Button("Clear Monitor History") {
                    store.clear()
                }
                .font(.inspectRootCaptionSemibold)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("monitor.clear")
            }
        }
    }
}
