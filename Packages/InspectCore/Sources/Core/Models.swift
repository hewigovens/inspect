import Foundation

public struct TLSInspectionReport: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let requestedURL: URL
    public let host: String
    public let networkProtocolName: String?
    public let trust: TrustSummary
    public let security: SecurityAssessment
    public let certificates: [CertificateDetails]

    public init(
        requestedURL: URL,
        host: String,
        networkProtocolName: String?,
        trust: TrustSummary,
        security: SecurityAssessment,
        certificates: [CertificateDetails]
    ) {
        self.requestedURL = requestedURL
        self.host = host
        self.networkProtocolName = networkProtocolName
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

public struct TrustSummary: Sendable, Equatable {
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
            return "Validation Failed"
        }
        return "Unchecked"
    }
}

public struct CertificateDetails: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let isLeaf: Bool
    public let isRoot: Bool
    public let subject: [LabeledValue]
    public let issuer: [LabeledValue]
    public let validity: ValidityPeriod
    public let serialNumber: String
    public let version: String
    public let signatureAlgorithm: String
    public let signature: String
    public let publicKey: PublicKeyDetails
    public let keyUsage: [String]
    public let extendedKeyUsage: [String]
    public let fingerprints: [LabeledValue]
    public let subjectAlternativeNames: [LabeledValue]
    public let policies: [LabeledValue]
    public let subjectKeyIdentifier: String?
    public let authorityKeyIdentifier: [LabeledValue]
    public let authorityInfoAccess: [LabeledValue]
    public let basicConstraints: [LabeledValue]
    public let extensions: [LabeledValue]
    public let derData: Data

    public init(
        id: String,
        title: String,
        isLeaf: Bool,
        isRoot: Bool,
        subject: [LabeledValue],
        issuer: [LabeledValue],
        validity: ValidityPeriod,
        serialNumber: String,
        version: String,
        signatureAlgorithm: String,
        signature: String,
        publicKey: PublicKeyDetails,
        keyUsage: [String],
        extendedKeyUsage: [String],
        fingerprints: [LabeledValue],
        subjectAlternativeNames: [LabeledValue],
        policies: [LabeledValue],
        subjectKeyIdentifier: String?,
        authorityKeyIdentifier: [LabeledValue],
        authorityInfoAccess: [LabeledValue],
        basicConstraints: [LabeledValue],
        extensions: [LabeledValue],
        derData: Data
    ) {
        self.id = id
        self.title = title
        self.isLeaf = isLeaf
        self.isRoot = isRoot
        self.subject = subject
        self.issuer = issuer
        self.validity = validity
        self.serialNumber = serialNumber
        self.version = version
        self.signatureAlgorithm = signatureAlgorithm
        self.signature = signature
        self.publicKey = publicKey
        self.keyUsage = keyUsage
        self.extendedKeyUsage = extendedKeyUsage
        self.fingerprints = fingerprints
        self.subjectAlternativeNames = subjectAlternativeNames
        self.policies = policies
        self.subjectKeyIdentifier = subjectKeyIdentifier
        self.authorityKeyIdentifier = authorityKeyIdentifier
        self.authorityInfoAccess = authorityInfoAccess
        self.basicConstraints = basicConstraints
        self.extensions = extensions
        self.derData = derData
    }

    public var subjectSummary: String {
        subject.first(where: { $0.label == "Common Name" })?.value ?? title
    }

    public var issuerSummary: String {
        issuer.first(where: { $0.label == "Common Name" })?.value ?? issuer.first?.value ?? "Unknown issuer"
    }

    public var commonNames: [String] {
        subject.filter { $0.label == "Common Name" }.map(\.value)
    }

    public var dnsNames: [String] {
        subjectAlternativeNames.filter { $0.label == "DNS Name" }.map(\.value)
    }

    public var ipAddresses: [String] {
        subjectAlternativeNames.filter { $0.label == "IP Address" }.map(\.value)
    }

    public var hostPatterns: [String] {
        let names = dnsNames + ipAddresses
        return names.isEmpty ? commonNames : names
    }

    public var isSelfIssued: Bool {
        guard subject.count == issuer.count else {
            return false
        }

        return zip(subject, issuer).allSatisfy { subjectEntry, issuerEntry in
            subjectEntry.label == issuerEntry.label && subjectEntry.value == issuerEntry.value
        }
    }
}

public struct PublicKeyDetails: Sendable, Equatable {
    public let algorithm: String
    public let bitSize: Int?
    public let hexRepresentation: String
    public let spkiSHA256Fingerprint: String

    public init(algorithm: String, bitSize: Int?, hexRepresentation: String, spkiSHA256Fingerprint: String) {
        self.algorithm = algorithm
        self.bitSize = bitSize
        self.hexRepresentation = hexRepresentation
        self.spkiSHA256Fingerprint = spkiSHA256Fingerprint
    }
}

public struct ValidityPeriod: Sendable, Equatable {
    public let notBefore: Date?
    public let notAfter: Date?

    public init(notBefore: Date?, notAfter: Date?) {
        self.notBefore = notBefore
        self.notAfter = notAfter
    }

    public var status: CertificateValidityStatus {
        let now = Date()

        if let notBefore, now < notBefore {
            return .notYetValid
        }

        if let notAfter, now > notAfter {
            return .expired
        }

        return .valid
    }
}

public enum CertificateValidityStatus: String, Sendable {
    case valid = "Valid"
    case expired = "Expired"
    case notYetValid = "Not Yet Valid"
}

public struct LabeledValue: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct SecurityAssessment: Sendable, Equatable {
    public let findings: [SecurityFinding]

    public init(findings: [SecurityFinding]) {
        self.findings = findings
    }

    public var criticalCount: Int {
        findings.filter { $0.severity == .critical }.count
    }

    public var warningCount: Int {
        findings.filter { $0.severity == .warning }.count
    }

    public var infoCount: Int {
        findings.filter { $0.severity == .info }.count
    }

    public var goodCount: Int {
        findings.filter { $0.severity == .good }.count
    }

    public var headline: String {
        if criticalCount > 0 {
            return "\(criticalCount) critical signal\(criticalCount == 1 ? "" : "s")"
        }

        if warningCount > 0 {
            return "\(warningCount) warning\(warningCount == 1 ? "" : "s")"
        }

        if findings.isEmpty {
            return "No security findings"
        }

        return "Security checks completed"
    }

    public var showsHeadline: Bool {
        criticalCount > 0 || warningCount > 0
    }
}

public struct SecurityFinding: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let severity: SecurityFindingSeverity
    public let title: String
    public let message: String

    public init(severity: SecurityFindingSeverity, title: String, message: String) {
        self.severity = severity
        self.title = title
        self.message = message
    }
}

public enum SecurityFindingSeverity: String, Sendable {
    case good = "Good"
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
}

public enum InspectionError: LocalizedError, Sendable {
    case invalidURL(String)
    case unsupportedScheme(String?)
    case missingServerTrust

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let raw):
            return "'\(raw)' is not a valid HTTPS URL."
        case .unsupportedScheme(let scheme):
            return "Only HTTPS URLs are supported. Received: \(scheme ?? "unknown")."
        case .missingServerTrust:
            return "The TLS handshake finished without exposing a server trust chain."
        }
    }
}

extension Date {
    public var inspectDisplayString: String {
        DateFormatter.inspectDisplayFormatter.string(from: self)
    }
}

private extension DateFormatter {
    static let inspectDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
