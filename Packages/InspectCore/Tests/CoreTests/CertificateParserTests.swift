import Crypto
import Foundation
import InspectCore
import Security
import SwiftASN1
import Testing
import X509

@Test
func normalizesBareHostInputToHTTPS() throws {
    let normalized = try URLInputNormalizer.normalize(input: "example.com")
    #expect(normalized.absoluteString == "https://example.com/")
}

@Test
func rejectsNonHTTPSURLs() throws {
    #expect(throws: InspectionError.self) {
        try URLInputNormalizer.normalize(input: "http://example.com")
    }
}

@Test
func parsesEmbeddedFixtureCertificate() throws {
    let fixtureURL = try #require(inspectTestFixtureURL(named: "mac_dev", extension: "cer"))
    let data = try Data(contentsOf: fixtureURL) as CFData
    let certificate = try #require(SecCertificateCreateWithData(nil, data))

    let parsed = CertificateParser().parse(certificates: [certificate])
    let leaf = try #require(parsed.first)

    #expect(leaf.title.contains("Mac Developer"))
    #expect(leaf.subject.contains(where: { $0.label == "Common Name" }))
    #expect(leaf.fingerprints.contains(where: { $0.label == "SHA-256" }))
    #expect(leaf.publicKey.algorithm == "RSA")
}

@Test
func parsesGeneratedExtensionsIntoStructuredFields() throws {
    let parsed = CertificateParser().parse(certificates: try makeGeneratedChain())
    let leaf = try #require(parsed.first)
    let root = try #require(parsed.last)

    #expect(leaf.subjectAlternativeNames.contains(where: { $0.label == "DNS Name" && $0.value == "example.com" }))
    #expect(leaf.subjectAlternativeNames.contains(where: { $0.label == "IP Address" && $0.value == "127.0.0.1" }))
    #expect(leaf.keyUsage.contains("digitalSignature"))
    #expect(leaf.keyUsage.contains("keyEncipherment"))
    #expect(leaf.extendedKeyUsage.contains("TLS Web Server Authentication"))
    #expect(leaf.subjectKeyIdentifier != nil)
    #expect(leaf.authorityKeyIdentifier.contains(where: { $0.label == "Key Identifier" }))
    #expect(leaf.authorityInfoAccess.contains(where: { $0.label == "OCSP Server" }))
    #expect(leaf.policies.contains(where: { $0.label == "Policy #1 Identifier" && $0.value == "1.2.3.4.5.6.7.8.1" }))
    #expect(leaf.policies.contains(where: { $0.label == "Policy #1 CPS URI" }))
    #expect(leaf.policies.contains(where: { $0.label == "Policy #1 User Notice" }))
    #expect(leaf.publicKey.spkiSHA256Fingerprint.isEmpty == false)
    #expect(root.basicConstraints.contains(where: { $0.label == "Certificate Authority" && $0.value == "Yes" }))

    #expect(leaf.sctList.contains(where: { $0.label == "SCT #1 Timestamp" }))
    #expect(leaf.sctList.contains(where: { $0.label == "SCT #1 Algorithm" && $0.value == "ECDSA with SHA-256" }))
    #expect(leaf.sctList.contains(where: { $0.label == "SCT #1 Signature" }))
    #expect(leaf.sctList.contains(where: { $0.label == "SCT #1 Log" }))

    #expect(leaf.crlDistributionPoints.contains(where: { $0.value == "http://crl.example.test/ca.crl" }))
    #expect(leaf.crlDistributionPoints.contains(where: { $0.value == "http://crl2.example.test/ca.crl" }))
}

@Test
func securityAnalyzerFlagsTrustFailureAndHostnameMismatch() throws {
    let parsed = CertificateParser().parse(certificates: try makeGeneratedChain())
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://mismatch.example")!,
        trust: TrustSummary(evaluated: true, isTrusted: false, failureReason: "Untrusted root"),
        certificates: parsed
    )

    #expect(assessment.findings.contains(where: { $0.title == "Trust Evaluation Failed" && $0.severity == .critical }))
    #expect(assessment.findings.contains(where: { $0.title == "Hostname Mismatch" && $0.severity == .critical }))
}

@Test
func securityAnalyzerLeavesHealthyChainWithoutWarnings() throws {
    let parsed = CertificateParser().parse(certificates: try makeGeneratedChain())
    let assessment = SecurityAnalyzer().analyze(
        requestedURL: URL(string: "https://example.com")!,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        certificates: parsed
    )

    #expect(assessment.criticalCount == 0)
    #expect(assessment.warningCount == 0)
    #expect(assessment.goodCount >= 2)
}

@Test
func securityAnalyzerFlagsInterceptionSignals() throws {
    let parsed = CertificateParser().parse(certificates: try makeGeneratedChain())
    let leaf = try #require(parsed.first)
    let suspiciousLeaf = CertificateDetails(
        id: leaf.id,
        title: leaf.title,
        isLeaf: leaf.isLeaf,
        isRoot: leaf.isRoot,
        subject: leaf.subject,
        issuer: [LabeledValue(label: "Organization", value: "Zscaler Root CA")],
        validity: leaf.validity,
        serialNumber: leaf.serialNumber,
        version: leaf.version,
        signatureAlgorithm: leaf.signatureAlgorithm,
        signature: leaf.signature,
        publicKey: leaf.publicKey,
        keyUsage: leaf.keyUsage + ["keyCertSign"],
        extendedKeyUsage: leaf.extendedKeyUsage,
        fingerprints: leaf.fingerprints,
        subjectAlternativeNames: leaf.subjectAlternativeNames,
        policies: leaf.policies,
        subjectKeyIdentifier: leaf.subjectKeyIdentifier,
        authorityKeyIdentifier: leaf.authorityKeyIdentifier,
        authorityInfoAccess: leaf.authorityInfoAccess,
        basicConstraints: [LabeledValue(label: "Certificate Authority", value: "Yes")],
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

    #expect(assessment.findings.contains(where: { $0.title == "Leaf Marked As Certificate Authority" && $0.severity == .critical }))
    #expect(assessment.findings.contains(where: { $0.title == "Leaf Can Sign Certificates" && $0.severity == .warning }))
    #expect(assessment.findings.contains(where: { $0.title == "Possible TLS Interception Product" && $0.message.contains("Zscaler") }))
}

private func makeGeneratedChain() throws -> [SecCertificate] {
    let now = Date().addingTimeInterval(-60 * 60)

    let rootPrivateKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let rootSubject = try DistinguishedName {
        OrganizationName("Inspect Test CA")
        CommonName("Inspect Root CA")
    }
    let rootSubjectKeyIdentifier = SubjectKeyIdentifier(hash: rootPrivateKey.publicKey)

    let rootExtensions = try Certificate.Extensions {
        Critical(BasicConstraints.isCertificateAuthority(maxPathLength: 0))
        Critical(KeyUsage(keyCertSign: true, cRLSign: true))
        rootSubjectKeyIdentifier
    }

    let rootCertificate = try Certificate(
        version: .v3,
        serialNumber: .init(bytes: [0x10, 0x01]),
        publicKey: rootPrivateKey.publicKey,
        notValidBefore: now,
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365),
        issuer: rootSubject,
        subject: rootSubject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: rootExtensions,
        issuerPrivateKey: rootPrivateKey
    )

    let leafPrivateKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
    let leafSubject = try DistinguishedName {
        OrganizationName("Inspect Test Site")
        CommonName("example.com")
    }
    let leafSubjectKeyIdentifier = SubjectKeyIdentifier(hash: leafPrivateKey.publicKey)

    let authorityInformationAccess = AuthorityInformationAccess([
        .init(method: .ocspServer, location: .uniformResourceIdentifier("http://ocsp.example.test")),
        .init(method: .issuingCA, location: .uniformResourceIdentifier("http://ca.example.test/issuer.der"))
    ])

    let leafExtensions = try Certificate.Extensions {
        Critical(BasicConstraints.notCertificateAuthority)
        Critical(KeyUsage(digitalSignature: true, keyEncipherment: true))
        try ExtendedKeyUsage([.serverAuth])
        SubjectAlternativeNames([
            .dnsName("example.com"),
            .dnsName("www.example.com"),
            .ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1][...]))
        ])
        leafSubjectKeyIdentifier
        AuthorityKeyIdentifier(keyIdentifier: rootSubjectKeyIdentifier.keyIdentifier)
        authorityInformationAccess
        try makePolicyExtension()
        try makeSCTExtension()
        try makeCRLDistributionPointsExtension()
    }

    let leafCertificate = try Certificate(
        version: .v3,
        serialNumber: .init(bytes: [0x20, 0x01]),
        publicKey: leafPrivateKey.publicKey,
        notValidBefore: now,
        notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 90),
        issuer: rootSubject,
        subject: leafSubject,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: leafExtensions,
        issuerPrivateKey: rootPrivateKey
    )

    return [
        try SecCertificate.makeWithCertificate(leafCertificate),
        try SecCertificate.makeWithCertificate(rootCertificate)
    ]
}

private func makePolicyExtension() throws -> Certificate.Extension {
    let cpsQualifier = try PolicyQualifierInfo(
        id: [1, 3, 6, 1, 5, 5, 7, 2, 1],
        qualifier: ASN1Any(erasing: ASN1IA5String("https://policy.example.test/cps"))
    )
    let userNoticeQualifier = try PolicyQualifierInfo(
        id: [1, 3, 6, 1, 5, 5, 7, 2, 2],
        qualifier: ASN1Any(erasing: UserNotice(explicitText: "Inspection policy notice"))
    )

    let policies = CertificatePoliciesValue([
        .init(
            identifier: [1, 2, 3, 4, 5, 6, 7, 8, 1],
            qualifiers: [cpsQualifier, userNoticeQualifier]
        )
    ])

    var serializer = DER.Serializer()
    try serializer.serialize(policies)

    return Certificate.Extension(
        oid: [2, 5, 29, 32],
        critical: false,
        value: serializer.serializedBytes[...]
    )
}

private struct CertificatePoliciesValue: DERSerializable {
    let policies: [PolicyInformation]

    init(_ policies: [PolicyInformation]) {
        self.policies = policies
    }

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            for policy in policies {
                try coder.serialize(policy)
            }
        }
    }
}

private struct PolicyInformation: DERSerializable {
    let identifier: ASN1ObjectIdentifier
    let qualifiers: [PolicyQualifierInfo]

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            try coder.serialize(identifier)
            if qualifiers.isEmpty == false {
                try coder.appendConstructedNode(identifier: .sequence) { coder in
                    for qualifier in qualifiers {
                        try coder.serialize(qualifier)
                    }
                }
            }
        }
    }
}

private struct PolicyQualifierInfo: DERSerializable {
    let id: ASN1ObjectIdentifier
    let qualifier: ASN1Any

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            try coder.serialize(id)
            try coder.serialize(qualifier)
        }
    }
}

private struct UserNotice: DERSerializable {
    let explicitText: ASN1UTF8String

    init(explicitText: String) {
        self.explicitText = ASN1UTF8String(explicitText)
    }

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            try coder.serialize(explicitText)
        }
    }
}

private func makeSCTExtension() throws -> Certificate.Extension {
    let logID = [UInt8](repeating: 0xAA, count: 32)
    let timestamp: UInt64 = 1_710_500_000_000
    let fakeSignature: [UInt8] = [0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x01]

    var sctData: [UInt8] = []
    sctData.append(0x00)
    sctData.append(contentsOf: logID)
    sctData.append(contentsOf: withUnsafeBytes(of: timestamp.bigEndian) { Array($0) })
    sctData.append(contentsOf: [0x00, 0x00])
    sctData.append(0x04)
    sctData.append(0x03)
    let sigLen = UInt16(fakeSignature.count)
    sctData.append(contentsOf: withUnsafeBytes(of: sigLen.bigEndian) { Array($0) })
    sctData.append(contentsOf: fakeSignature)

    let sctLen = UInt16(sctData.count)
    var sctListPayload: [UInt8] = []
    sctListPayload.append(contentsOf: withUnsafeBytes(of: sctLen.bigEndian) { Array($0) })
    sctListPayload.append(contentsOf: sctData)

    let totalLen = UInt16(sctListPayload.count)
    var tlsEncoded: [UInt8] = []
    tlsEncoded.append(contentsOf: withUnsafeBytes(of: totalLen.bigEndian) { Array($0) })
    tlsEncoded.append(contentsOf: sctListPayload)

    var serializer = DER.Serializer()
    try serializer.serialize(ASN1OctetString(contentBytes: tlsEncoded[...]))

    return Certificate.Extension(
        oid: [1, 3, 6, 1, 4, 1, 11129, 2, 4, 2],
        critical: false,
        value: serializer.serializedBytes[...]
    )
}

private func makeCRLDistributionPointsExtension() throws -> Certificate.Extension {
    let tag0 = ASN1Identifier(tagWithNumber: 0, tagClass: .contextSpecific)
    let uriTag = ASN1Identifier(tagWithNumber: 6, tagClass: .contextSpecific)

    var serializer = DER.Serializer()
    try serializer.appendConstructedNode(identifier: .sequence) { coder in
        for uri in ["http://crl.example.test/ca.crl", "http://crl2.example.test/ca.crl"] {
            try coder.appendConstructedNode(identifier: .sequence) { dpCoder in
                try dpCoder.appendConstructedNode(identifier: tag0) { dpNameCoder in
                    try dpNameCoder.appendConstructedNode(identifier: tag0) { gnCoder in
                        let uriBytes = Array(uri.utf8)
                        try gnCoder.serialize(ASN1OctetString(contentBytes: uriBytes[...]), withIdentifier: uriTag)
                    }
                }
            }
        }
    }

    return Certificate.Extension(
        oid: [2, 5, 29, 31],
        critical: false,
        value: serializer.serializedBytes[...]
    )
}

private extension DER.Serializer {
    mutating func serialize(_ value: ASN1OctetString, withIdentifier identifier: ASN1Identifier) throws {
        let bytes = Array(value.bytes)
        appendPrimitiveNode(identifier: identifier) { content in
            content.append(contentsOf: bytes)
        }
    }
}
