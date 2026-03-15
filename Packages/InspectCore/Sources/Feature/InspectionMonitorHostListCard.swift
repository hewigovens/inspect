import SwiftUI

struct InspectionMonitorHostListCard: View {
    @Bindable var store: InspectionMonitorStore
    @Binding var searchText: String
    @Binding var filter: InspectionMonitorHostFilter

    private var monitoredHosts: [InspectionMonitoredHost] {
        store.monitoredHosts.filter(matchesCurrentFilter)
    }

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                header

                if monitoredHosts.isEmpty {
                    Text(emptyStateDescription)
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

            Menu {
                ForEach(InspectionMonitorHostFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        if option == filter {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                Label(filter.title, systemImage: "line.3.horizontal.decrease.circle")
                    .font(.inspectRootCaptionSemibold)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }

            Text("\(monitoredHosts.count)")
                .font(.inspectRootCaptionSemibold)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateDescription: String {
        if store.monitoredHosts.isEmpty {
            return "No hosts found yet. Keep Live Monitor enabled and browse websites to populate traffic."
        }

        return "No hosts match the current search or filter."
    }

    private func matchesCurrentFilter(_ host: InspectionMonitoredHost) -> Bool {
        guard filter.includes(host) else {
            return false
        }

        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.isEmpty == false else {
            return true
        }

        let query = normalizedQuery.localizedLowercase
        if host.host.localizedLowercase.contains(query) {
            return true
        }

        if host.subtitle.localizedLowercase.contains(query) {
            return true
        }

        return false
    }
}
