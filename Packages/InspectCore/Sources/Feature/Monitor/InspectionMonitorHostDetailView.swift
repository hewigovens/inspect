import InspectCore
import SwiftUI

struct InspectionMonitorHostDetailView: View {
    @Bindable var store: InspectionMonitorStore
    let host: InspectionMonitoredHost
    @State private var certificateRoute: InspectionCertificateRoute?

    private var latestReport: TLSInspectionReport? {
        host.latestReport ?? store.latestCapturedReport(forHost: host.host)
    }

    private var history: [InspectionMonitorEntry] {
        store.entries(forHost: host.host)
    }

    var body: some View {
        ZStack {
            InspectBackground()
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 18) {
                    summaryCard
                    certificateCard
                    historyCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle(host.host)
        .inlineRootNavigationTitle()
        .certificateDetailDestination($certificateRoute)
    }

    private var summaryCard: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(host.host)
                    .font(.inspectRootHeadline)

                monitorMetricRow(label: "Status", value: host.statusTitle)
                monitorMetricRow(label: "Certificate", value: host.certificateAvailability.title)
                monitorMetricRow(label: "First Seen", value: host.firstSeenAt.formatted(date: .abbreviated, time: .shortened))
                monitorMetricRow(label: "Last Seen", value: host.lastSeenAt.formatted(date: .abbreviated, time: .shortened))

                if let remoteHost = host.lastEvent.observation.remoteHost {
                    monitorMetricRow(label: "Endpoint", value: remoteHost)
                }

                if let serverName = host.lastEvent.observation.serverName {
                    monitorMetricRow(label: "SNI", value: serverName)
                }

                if let remotePort = host.lastEvent.observation.remotePort {
                    monitorMetricRow(label: "Port", value: String(remotePort))
                }

                if let note = history.first?.note {
                    Text(note)
                        .font(.inspectRootCaptionSemibold)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var certificateCard: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Certificate")
                    .font(.inspectRootHeadline)

                if let report = latestReport {
                    if let leaf = report.leafCertificate {
                        monitorMetricRow(label: "Leaf", value: leaf.subjectSummary)
                        monitorMetricRow(label: "Issuer", value: leaf.issuerSummary)
                    }

                    monitorMetricRow(label: "Trust", value: host.statusTitle)

                    Button {
                        certificateRoute = InspectionCertificateRoute(
                            inspection: TLSInspection(report: report),
                            initialReportIndex: 0,
                            initialSelectionIndex: 0
                        )
                    } label: {
                        HStack(spacing: 10) {
                            Text("View Certificate Chain")
                                .font(.inspectRootSubheadlineSemibold)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.inspectRootCaptionBold)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No certificate chain has been captured for this host yet. Keep Live Monitor running or inspect it manually.")
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var historyCard: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Recent Activity")
                        .font(.inspectRootHeadline)

                    Spacer()

                    Text("\(history.count)")
                        .font(.inspectRootCaptionSemibold)
                        .foregroundStyle(.secondary)
                }

                if history.isEmpty {
                    Text("No recorded events for this host yet.")
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history.prefix(12)) { entry in
                        MonitorEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private func monitorMetricRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.inspectRootCaptionBold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.inspectRootSubheadline)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}
