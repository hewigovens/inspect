import Foundation

public struct CertificateDetails: Identifiable, Sendable, Equatable, Codable {
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

public struct PublicKeyDetails: Sendable, Equatable, Codable {
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

public struct ValidityPeriod: Sendable, Equatable, Codable {
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

public enum CertificateValidityStatus: String, Sendable, Codable {
    case valid = "Valid"
    case expired = "Expired"
    case notYetValid = "Not Yet Valid"
}

public struct LabeledValue: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let label: String
    public let value: String

    public init(id: UUID = UUID(), label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}
