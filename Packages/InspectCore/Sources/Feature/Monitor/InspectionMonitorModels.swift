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

    var daysUntilExpiry: Int? {
        guard let notAfter = latestReport?.leafCertificate?.validity.notAfter else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: notAfter).day
    }

    var expiryWarning: String? {
        guard let days = daysUntilExpiry else { return nil }
        if days < 0 { return "Expired" }
        if days == 0 { return "Expires today" }
        if days <= 30 { return "Expires in \(days)d" }
        return nil
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

enum InspectionMonitorHostFilter: String, CaseIterable, Identifiable {
    case all
    case trusted
    case review
    case pending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .trusted:
            return "Trusted"
        case .review:
            return "Review"
        case .pending:
            return "Pending"
        }
    }

    func includes(_ host: InspectionMonitoredHost) -> Bool {
        switch self {
        case .all:
            return true
        case .trusted:
            return host.state == .trusted
        case .review:
            return host.state == .needsReview
        case .pending:
            return host.certificateAvailability == .pending
        }
    }
}
