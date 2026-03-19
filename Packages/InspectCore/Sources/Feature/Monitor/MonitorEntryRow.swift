import SwiftUI

struct MonitorEntryRow: View {
    let entry: InspectionMonitorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(hostText)
                    .font(.inspectRootSubheadlineSemibold)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(statusTitle)
                    .font(.inspectRootCaptionSemibold)
                    .foregroundStyle(statusTint)
            }

            Text(detailText)
                .font(.inspectRootCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let note = entry.note {
                Text(note)
                    .font(.inspectRootCaptionSemibold)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hostText: String {
        switch entry.event.result {
        case let .captured(report):
            return report.host
        case .failed, .skippedMissingHost, .skippedThrottled:
            return entry.event.observation.probeHost
                ?? entry.event.observation.remoteHost
                ?? "Unknown Host"
        }
    }

    private var statusTitle: String {
        switch entry.event.result {
        case let .captured(report):
            return report.trust.badgeText
        case .skippedMissingHost:
            return entry.event.observation.remoteHost == nil ? "No Host" : "IP Only"
        case .skippedThrottled:
            return "Throttled"
        case .failed:
            return "Probe Failed"
        }
    }

    private var statusTint: Color {
        switch entry.event.result {
        case let .captured(report):
            return report.trust.isTrusted ? .green : .orange
        case .skippedMissingHost:
            return entry.event.observation.remoteHost == nil ? .secondary : .orange
        case .skippedThrottled:
            return .blue
        case .failed:
            return .red
        }
    }

    private var detailText: String {
        let observedAt = entry.event.occurredAt.formatted(date: .omitted, time: .shortened)

        switch entry.event.result {
        case let .captured(report):
            if let leaf = report.leafCertificate {
                return "\(observedAt) • \(leaf.issuerSummary)"
            }
            return "\(observedAt) • Certificate chain captured"
        case let .failed(reason):
            return "\(observedAt) • \(reason)"
        case .skippedMissingHost:
            if let remoteHost = entry.event.observation.remoteHost {
                return "\(observedAt) • Observed endpoint \(remoteHost) without hostname (SNI missing)."
            }
            return "\(observedAt) • Flow did not include host metadata."
        case let .skippedThrottled(until):
            let retryAt = until.formatted(date: .omitted, time: .shortened)
            return "\(observedAt) • Next probe after \(retryAt)."
        }
    }
}
