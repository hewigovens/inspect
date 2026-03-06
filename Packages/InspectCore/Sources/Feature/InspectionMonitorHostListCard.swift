import SwiftUI

struct InspectionMonitorHostListCard: View {
    @Bindable var store: InspectionMonitorStore

    private var monitoredHosts: [InspectionMonitoredHost] {
        store.monitoredHosts
    }

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                header

                if monitoredHosts.isEmpty {
                    Text("No hosts found yet. Keep Live Monitor enabled and browse websites to populate traffic.")
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(monitoredHosts) { host in
                            NavigationLink {
                                InspectionMonitorHostDetailView(store: store, host: host)
                            } label: {
                                MonitoredHostRow(host: host)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hosts")
                    .font(.inspectRootHeadline)

                Text("Observed domains and endpoints from live traffic.")
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(monitoredHosts.count)")
                .font(.inspectRootCaptionSemibold)
                .foregroundStyle(.secondary)
        }
    }
}
