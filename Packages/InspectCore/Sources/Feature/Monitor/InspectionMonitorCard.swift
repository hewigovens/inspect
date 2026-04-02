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
        _store = Bindable(store)
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
                    Text("Turn on Live Monitor to populate hosts.")
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
                Text("Observed hosts and latest certificates.")
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { store.isEnabled },
                set: { store.setEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(store.isApplyingLiveMonitorToggle)
            .accessibilityIdentifier("monitor.toggle")
        }
    }

    @ViewBuilder
    private var enabledContent: some View {
        HStack(spacing: 12) {
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

            Spacer()

            NavigationLink {
                InspectionDiagnosticsView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                    Text("Diagnostics")
                }
                .font(.inspectRootCaptionSemibold)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("monitor.diagnostics")
        }

        HStack(spacing: 12) {
            monitorMetric(
                title: "Hosts",
                value: "\(store.hostCount)"
            )

            Divider()
                .frame(height: 34)

            monitorMetric(
                title: "Last Activity",
                value: store.lastActivityTitle
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.inspectChromeFill)
        )

        if store.hostCount == 0 {
            Text("Browse with Live Monitor on to populate hosts.")
                .font(.inspectRootCaption)
                .foregroundStyle(.secondary)
        } else {
            Text("Tap a host for details.")
                .font(.inspectRootCaption)
                .foregroundStyle(.secondary)
        }
    }

    private func monitorMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.inspectRootCaptionBold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.inspectRootSubheadlineSemibold)
                .foregroundStyle(.primary)
        }
    }
}
