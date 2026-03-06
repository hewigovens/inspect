import Foundation
import InspectCore

struct InspectionMonitorEntry: Identifiable, Equatable {
    let id: UUID
    let event: TLSProbeEvent
    let note: String?

    init(event: TLSProbeEvent, note: String?) {
        self.id = event.id
        self.event = event
        self.note = note
    }
}

struct InspectionMonitoredHost: Identifiable, Equatable {
    let host: String
    let lastEvent: TLSProbeEvent
    let supportsActiveProbe: Bool

    var id: String { host }

    var statusTitle: String {
        switch lastEvent.result {
        case let .captured(report):
            return report.trust.badgeText
        case .skippedMissingHost:
            return supportsActiveProbe ? "No Host" : "IP Only"
        case .skippedThrottled:
            return "Throttled"
        case .failed:
            return "Probe Failed"
        }
    }

    var subtitle: String {
        let timestamp = lastEvent.occurredAt.formatted(date: .omitted, time: .shortened)

        switch lastEvent.result {
        case let .captured(report):
            if let issuer = report.leafCertificate?.issuerSummary {
                return "\(timestamp) • \(issuer)"
            }
            return "\(timestamp) • Certificate chain captured"
        case let .failed(reason):
            return "\(timestamp) • \(reason)"
        case .skippedMissingHost:
            if supportsActiveProbe {
                return "\(timestamp) • Flow did not include host metadata."
            }
            return "\(timestamp) • Endpoint observed without hostname (SNI missing)."
        case let .skippedThrottled(until):
            return "\(timestamp) • Next probe after \(until.formatted(date: .omitted, time: .shortened))."
        }
    }
}
