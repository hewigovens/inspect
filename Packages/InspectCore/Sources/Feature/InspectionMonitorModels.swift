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

enum InspectionMonitoredHostState: Equatable {
    case trusted
    case needsReview
    case awaitingCertificate
    case hostnameUnavailable

    var title: String {
        switch self {
        case .trusted:
            return "Trusted"
        case .needsReview:
            return "Review"
        case .awaitingCertificate:
            return "Seen"
        case .hostnameUnavailable:
            return "IP Only"
        }
    }
}

enum InspectionMonitoredHostCertificateAvailability: Equatable {
    case captured
    case pending

    var title: String {
        switch self {
        case .captured:
            return "Captured"
        case .pending:
            return "Pending"
        }
    }
}

struct InspectionMonitoredHost: Identifiable, Equatable {
    let host: String
    let lastEvent: TLSProbeEvent
    let firstSeenAt: Date
    let lastSeenAt: Date
    let latestReport: TLSInspectionReport?
    let state: InspectionMonitoredHostState
    let certificateAvailability: InspectionMonitoredHostCertificateAvailability

    var id: String { host }

    var statusTitle: String {
        state.title
    }

    var subtitle: String {
        let timestamp = lastSeenAt.formatted(date: .omitted, time: .shortened)

        if let report = latestReport {
            if let issuer = report.leafCertificate?.issuerSummary {
                return "\(timestamp) • \(issuer)"
            }
            return "\(timestamp) • Certificate chain captured"
        }

        switch state {
        case .trusted, .needsReview:
            return "\(timestamp) • Certificate chain captured"
        case .awaitingCertificate:
            return "\(timestamp) • Awaiting certificate capture"
        case .hostnameUnavailable:
            return "\(timestamp) • Hostname unavailable in observed flow"
        }
    }
}
