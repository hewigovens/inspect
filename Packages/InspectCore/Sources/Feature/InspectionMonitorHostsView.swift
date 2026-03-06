import SwiftUI

struct InspectionMonitorHostsView: View {
    @Bindable var store: InspectionMonitorStore
    private var monitoredHosts: [InspectionMonitoredHost] { store.monitoredHosts }

    var body: some View {
        List {
            content
        }
        .navigationTitle("Live Monitor")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        if monitoredHosts.isEmpty {
            emptySection
        } else {
            hostsSection
        }
    }

    private var emptySection: some View {
        Section {
            Text("No hosts found yet. Keep Live Monitor enabled and browse websites to populate traffic.")
                .font(.inspectRootCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var hostsSection: some View {
        Section {
            ForEach(monitoredHosts) { host in
                hostRow(host)
            }
        } header: {
            Text("Found Hosts")
        } footer: {
            Text("Observed hosts from Live Monitor traffic.")
                .font(.inspectRootCaption)
        }
    }

    private func hostRow(_ host: InspectionMonitoredHost) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(host.host)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(host.subtitle)
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(host.statusTitle)
                .font(.inspectRootCaptionSemibold)
                .foregroundStyle(host.supportsActiveProbe ? Color.secondary : Color.orange)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("monitor.host.\(host.id)")
    }
}
