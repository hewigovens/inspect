import Foundation

public struct TLSInspectionReport: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let requestedURL: URL
    public let host: String
    public let networkProtocolName: String?
    public let tlsVersion: String?
    public let cipherSuite: String?
    public let trust: TrustSummary
    public let security: SecurityAssessment
    public let certificates: [CertificateDetails]

    public init(
        id: UUID = UUID(),
        requestedURL: URL,
        host: String,
        networkProtocolName: String?,
        tlsVersion: String? = nil,
        cipherSuite: String? = nil,
        trust: TrustSummary,
        security: SecurityAssessment,
        certificates: [CertificateDetails]
    ) {
        self.id = id
        self.requestedURL = requestedURL
        self.host = host
        self.networkProtocolName = networkProtocolName
        self.tlsVersion = tlsVersion
        self.cipherSuite = cipherSuite
        self.trust = trust
        self.security = security
        self.certificates = certificates
    }

    public var leafCertificate: CertificateDetails? {
        certificates.first
    }

    public var sslLabsURL: URL? {
        URL(string: "https://www.ssllabs.com/ssltest/analyze.html?hideResults=on&d=\(host)")
    }
}

public struct TrustSummary: Sendable, Equatable, Codable {
    public let evaluated: Bool
    public let isTrusted: Bool
    public let failureReason: String?

    public init(evaluated: Bool, isTrusted: Bool, failureReason: String?) {
        self.evaluated = evaluated
        self.isTrusted = isTrusted
        self.failureReason = failureReason
    }

    public var badgeText: String {
        if isTrusted {
            return "Trusted"
        }
        if evaluated {
            return "Failed"
        }
        return "Unchecked"
    }
}
