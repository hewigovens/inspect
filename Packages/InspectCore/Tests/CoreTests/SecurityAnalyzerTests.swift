import Crypto
import Foundation
import InspectCore
import Security
import SwiftASN1
import Testing
import X509

@Test
func securityAnalyzerReportsNoCertificateChain() {
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: false, failureReason: nil),
        certificates: []
    )

    #expect(assessment.findings.count == 1)
    #expect(assessment.findings.first?.title == "No Certificate Chain")
    #expect(assessment.findings.first?.severity == .critical)
}

@Test
func securityAnalyzerFlagsExpiredCertificate() throws {
    let certs = try makeChain(
        leafNotBefore: Date().addingTimeInterval(-60 * 60 * 24 * 400),
        leafNotAfter: Date().addingTimeInterval(-60 * 60 * 24 * 30)
    )
    let parsed = CertificateParser().parse(certificates: certs)
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: false, failureReason: nil),
        certificates: parsed
    )

    #expect(assessment.findings.contains(where: { $0.title == "Certificate Expired" && $0.severity == .critical }))
}

@Test
func securityAnalyzerFlagsNotYetValidCertificate() throws {
    let certs = try makeChain(
        leafNotBefore: Date().addingTimeInterval(60 * 60 * 24 * 30),
        leafNotAfter: Date().addingTimeInterval(60 * 60 * 24 * 365)
    )
    let parsed = CertificateParser().parse(certificates: certs)
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: false, failureReason: nil),
        certificates: parsed
    )

    #expect(assessment.findings.contains(where: { $0.title == "Certificate Not Yet Valid" && $0.severity == .critical }))
}

@Test
func securityAnalyzerFlagsSelfIssuedLeaf() throws {
    let certs = try makeSelfSignedLeaf()
    let parsed = CertificateParser().parse(certificates: certs)
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: false, failureReason: nil),
        certificates: parsed
    )

    #expect(assessment.findings.contains(where: { $0.title == "Self-Issued Leaf" }))
}

@Test
func securityAnalyzerFlagsMissingSAN() throws {
    let certs = try makeChainWithoutSAN()
    let parsed = CertificateParser().parse(certificates: certs)
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: false, failureReason: nil),
        certificates: parsed
    )

    #expect(assessment.findings.contains(where: { $0.title == "No Subject Alternative Name" && $0.severity == .warning }))
}

@Test
func securityAnalyzerFlagsMissingRevocationEndpoints() throws {
    let certs = try makeChainWithoutAIA()
    let parsed = CertificateParser().parse(certificates: certs)
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        certificates: parsed
    )

    #expect(assessment.findings.contains(where: { $0.title == "No Revocation Endpoints" && $0.severity == .info }))
}

@Test
func securityAnalyzerWildcardHostnameMatching() throws {
    let certs = try makeChain(sanNames: ["*.example.com"])
    let parsed = CertificateParser().parse(certificates: certs)

    let matchAssessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://www.example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        certificates: parsed
    )
    #expect(matchAssessment.findings.contains(where: { $0.title == "Hostname Covered" }))

    let mismatchAssessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://sub.sub.example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        certificates: parsed
    )
    #expect(mismatchAssessment.findings.contains(where: { $0.title == "Hostname Mismatch" }))
}

@Test(arguments: [
    ("burp", "Burp"),
    ("charles", "Charles"),
    ("fiddler", "Fiddler"),
    ("proxyman", "Proxyman"),
    ("mitmproxy", "mitmproxy"),
    ("netskope", "Netskope"),
    ("fortinet", "Fortinet")
])
func securityAnalyzerDetectsInterceptionProduct(keyword: String, label: String) throws {
    let certs = try makeChain()
    let parsed = CertificateParser().parse(certificates: certs)
    let leaf = try #require(parsed.first)

    let suspiciousLeaf = CertificateDetails(
        id: leaf.id,
        title: leaf.title,
        isLeaf: leaf.isLeaf,
        isRoot: leaf.isRoot,
        subject: leaf.subject,
        issuer: [LabeledValue(label: "Organization", value: "\(keyword) Root CA")],
        validity: leaf.validity,
        serialNumber: leaf.serialNumber,
        version: leaf.version,
        signatureAlgorithm: leaf.signatureAlgorithm,
        signature: leaf.signature,
        publicKey: leaf.publicKey,
        keyUsage: leaf.keyUsage,
        extendedKeyUsage: leaf.extendedKeyUsage,
        fingerprints: leaf.fingerprints,
        subjectAlternativeNames: leaf.subjectAlternativeNames,
        policies: leaf.policies,
        subjectKeyIdentifier: leaf.subjectKeyIdentifier,
        authorityKeyIdentifier: leaf.authorityKeyIdentifier,
        authorityInfoAccess: leaf.authorityInfoAccess,
        basicConstraints: leaf.basicConstraints,
        sctList: leaf.sctList,
        crlDistributionPoints: leaf.crlDistributionPoints,
        extensions: leaf.extensions,
        derData: leaf.derData
    )

    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        certificates: [suspiciousLeaf]
    )

    #expect(assessment.findings.contains(where: { $0.title == "Possible TLS Interception Product" && $0.message.contains(label) }))
}

// MARK: - Test Helpers

private func makeChain(
    leafNotBefore: Date? = nil,
    leafNotAfter: Date? = nil,
    sanNames: [String] = ["example.com"]
) throws -> [SecCertificate] {
    let now = Date().addingTimeInterval(-60 * 60)
    let rootKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let rootSubject = try DistinguishedName {
        OrganizationName("Test CA")
        CommonName("Test Root CA")
    }
    let rootSKI = SubjectKeyIdentifier(hash: rootKey.publicKey)

    let root = try Certificate(
        version: .v3,
        serialNumber: .init(bytes: [0x01]),
        publicKey: rootKey.publicKey,
        notValidBefore: now,
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365),
        issuer: rootSubject,
        subject: rootSubject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            Critical(BasicConstraints.isCertificateAuthority(maxPathLength: 0))
            rootSKI
        },
        issuerPrivateKey: rootKey
    )

    let leafKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let leafSubject = try DistinguishedName {
        CommonName(sanNames.first ?? "example.com")
    }

    let leaf = try Certificate(
        version: .v3,
        serialNumber: .init(bytes: [0x02]),
        publicKey: leafKey.publicKey,
        notValidBefore: leafNotBefore ?? now,
        notValidAfter: leafNotAfter ?? now.addingTimeInterval(60 * 60 * 24 * 90),
        issuer: rootSubject,
        subject: leafSubject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
            try ExtendedKeyUsage([.serverAuth])
            SubjectAlternativeNames(sanNames.map { .dnsName($0) })
            AuthorityKeyIdentifier(keyIdentifier: rootSKI.keyIdentifier)
            AuthorityInformationAccess([
                .init(method: .ocspServer, location: .uniformResourceIdentifier("http://ocsp.test"))
            ])
        },
        issuerPrivateKey: rootKey
    )

    return [
        try SecCertificate.makeWithCertificate(leaf),
        try SecCertificate.makeWithCertificate(root)
    ]
}

private func makeSelfSignedLeaf() throws -> [SecCertificate] {
    let now = Date().addingTimeInterval(-60 * 60)
    let key = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let subject = try DistinguishedName {
        CommonName("example.com")
    }

    let cert = try Certificate(
        version: .v3,
        serialNumber: .init(bytes: [0x01]),
        publicKey: key.publicKey,
        notValidBefore: now,
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365),
        issuer: subject,
        subject: subject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            SubjectAlternativeNames([.dnsName("example.com")])
        },
        issuerPrivateKey: key
    )

    return [try SecCertificate.makeWithCertificate(cert)]
}

private func makeChainWithoutSAN() throws -> [SecCertificate] {
    let now = Date().addingTimeInterval(-60 * 60)
    let key = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let subject = try DistinguishedName {
        CommonName("example.com")
    }

    let cert = try Certificate(
        version: .v3,
        serialNumber: .init(bytes: [0x01]),
        publicKey: key.publicKey,
        notValidBefore: now,
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 90),
        issuer: subject,
        subject: subject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            Critical(KeyUsage(digitalSignature: true))
            try ExtendedKeyUsage([.serverAuth])
        },
        issuerPrivateKey: key
    )

    return [try SecCertificate.makeWithCertificate(cert)]
}

private func makeChainWithoutAIA() throws -> [SecCertificate] {
    let now = Date().addingTimeInterval(-60 * 60)
    let key = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let subject = try DistinguishedName {
        CommonName("example.com")
    }

    let cert = try Certificate(
        version: .v3,
        serialNumber: .init(bytes: [0x01]),
        publicKey: key.publicKey,
        notValidBefore: now,
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 90),
        issuer: subject,
        subject: subject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            SubjectAlternativeNames([.dnsName("example.com")])
            try ExtendedKeyUsage([.serverAuth])
        },
        issuerPrivateKey: key
    )

    return [try SecCertificate.makeWithCertificate(cert)]
}
