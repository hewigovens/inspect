import SwiftUI

struct InspectionMonitorHostListCard: View {
    @Bindable var store: InspectionMonitorStore
    @Binding var searchText: String
    @Binding var filter: InspectionMonitorHostFilter
    @Binding var isSearchExpanded: Bool
    @FocusState.Binding var isSearchFocused: Bool

    private var monitoredHosts: [InspectionMonitoredHost] {
        store.monitoredHosts.filter(matchesCurrentFilter)
    }

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                header
                if usesInlineCardSearch, isSearchExpanded || searchText.isEmpty == false {
                    inlineSearchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Hosts")
                        .font(.inspectRootHeadline)

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

                Text("Observed domains and endpoints from live traffic.")
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if usesInlineCardSearch {
                searchToggle
            }
        }
    }

    private var searchToggle: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                isSearchExpanded.toggle()
            }
            if isSearchExpanded {
                isSearchFocused = true
            } else {
                isSearchFocused = false
                if searchText.isEmpty {
                    searchText = ""
                }
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSearchExpanded || searchText.isEmpty == false ? .white : .inspectAccent)
                .frame(
                    width: InspectLayout.Monitor.inlineSearchButtonSize,
                    height: InspectLayout.Monitor.inlineSearchButtonSize
                )
                .background(
                    Circle()
                        .fill(
                            isSearchExpanded || searchText.isEmpty == false
                                ? Color.inspectAccent
                                : Color.inspectChromeFill
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.inspectCardStroke, lineWidth: isSearchExpanded || searchText.isEmpty == false ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var inlineSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search Hosts", text: $searchText)
                .inspectURLField()
                .focused($isSearchFocused)

            if searchText.isEmpty == false {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                searchText = ""
                isSearchFocused = false
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isSearchExpanded = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.inspectChromeMutedFill)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.inspectChromeFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.inspectCardStroke, lineWidth: 1)
        )
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

    private var usesInlineCardSearch: Bool {
        InspectLayout.Monitor.usesInlineCardSearch
    }
}
