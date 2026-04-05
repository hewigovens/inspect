import InspectCore

enum CertificateRevocationTone: Equatable {
    case neutral
    case good
    case warning
    case critical
}

struct CertificateRevocationSummary: Equatable {
    let iconName: String
    let tone: CertificateRevocationTone
    let title: String
    let detail: String?
    let showsProgress: Bool

    static func make(
        host: String,
        status: RevocationStatus
    ) -> CertificateRevocationSummary {
        switch status {
        case .unchecked, .checking:
            return CertificateRevocationSummary(
                iconName: "arrow.trianglehead.2.clockwise.rotate.90",
                tone: .neutral,
                title: "Checking revocation…",
                detail: "Querying OCSP / CRL responders for the server certificate at \(host).",
                showsProgress: true
            )
        case .good:
            return CertificateRevocationSummary(
                iconName: "checkmark.shield.fill",
                tone: .good,
                title: "Not revoked",
                detail: "OCSP / CRL passed for the server certificate.",
                showsProgress: false
            )
        case .crlOnly:
            return CertificateRevocationSummary(
                iconName: "shield",
                tone: .neutral,
                title: "CRL-only issuer",
                detail: "This certificate advertises CRL distribution points but no OCSP responder, so positive revocation status is unavailable.",
                showsProgress: false
            )
        case let .revoked(reason):
            return CertificateRevocationSummary(
                iconName: "xmark.shield.fill",
                tone: .critical,
                title: "Revoked",
                detail: normalized(reason),
                showsProgress: false
            )
        case let .unreachable(reason):
            return CertificateRevocationSummary(
                iconName: "exclamationmark.shield",
                tone: .warning,
                title: "Inconclusive",
                detail: normalized(reason),
                showsProgress: false
            )
        }
    }

    private static func normalized(_ reason: String) -> String {
        let lowered = reason.lowercased()

        if lowered.contains("positive response") {
            return "The issuer did not return a usable OCSP / CRL response."
        }

        if lowered.contains("pinning requirements") {
            return "The returned revocation data did not satisfy the platform trust requirements."
        }

        if lowered.contains("standards compliant") {
            return "The responder returned revocation data that was not standards compliant."
        }

        if lowered.contains("offline") || lowered.contains("timed out") || lowered.contains("network") {
            return "Could not reach the OCSP / CRL responder."
        }

        return reason
    }
}
