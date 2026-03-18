import Foundation
import InspectCore
import Testing

@Test
func validCertificateStatusWhenWithinWindow() {
    let validity = ValidityPeriod(
        notBefore: Date().addingTimeInterval(-3600),
        notAfter: Date().addingTimeInterval(3600)
    )
    #expect(validity.status == .valid)
}

@Test
func expiredCertificateStatus() {
    let validity = ValidityPeriod(
        notBefore: Date().addingTimeInterval(-7200),
        notAfter: Date().addingTimeInterval(-3600)
    )
    #expect(validity.status == .expired)
}

@Test
func notYetValidCertificateStatus() {
    let validity = ValidityPeriod(
        notBefore: Date().addingTimeInterval(3600),
        notAfter: Date().addingTimeInterval(7200)
    )
    #expect(validity.status == .notYetValid)
}

@Test
func validWhenDatesAreNil() {
    let validity = ValidityPeriod(notBefore: nil, notAfter: nil)
    #expect(validity.status == .valid)
}

@Test
func subjectSummaryFallsBackToTitle() {
    let cert = makeCert(title: "My Cert", subject: [])
    #expect(cert.subjectSummary == "My Cert")
}

@Test
func subjectSummaryUsesCommonName() {
    let cert = makeCert(title: "My Cert", subject: [
        LabeledValue(label: "Organization", value: "Org"),
        LabeledValue(label: "Common Name", value: "example.com")
    ])
    #expect(cert.subjectSummary == "example.com")
}

@Test
func issuerSummaryFallsBackToUnknown() {
    let cert = makeCert(issuer: [])
    #expect(cert.issuerSummary == "Unknown issuer")
}

@Test
func issuerSummaryUsesFirstValueWhenNoCN() {
    let cert = makeCert(issuer: [
        LabeledValue(label: "Organization", value: "DigiCert")
    ])
    #expect(cert.issuerSummary == "DigiCert")
}

@Test
func dnsNamesFiltersCorrectly() {
    let cert = makeCert(sans: [
        LabeledValue(label: "DNS Name", value: "example.com"),
        LabeledValue(label: "IP Address", value: "1.2.3.4"),
        LabeledValue(label: "DNS Name", value: "www.example.com")
    ])
    #expect(cert.dnsNames == ["example.com", "www.example.com"])
    #expect(cert.ipAddresses == ["1.2.3.4"])
}

@Test
func hostPatternsFallsBackToCommonNames() {
    let cert = makeCert(
        subject: [LabeledValue(label: "Common Name", value: "fallback.com")],
        sans: []
    )
    #expect(cert.hostPatterns == ["fallback.com"])
}

@Test
func hostPatternsPrefersSANOverCN() {
    let cert = makeCert(
        subject: [LabeledValue(label: "Common Name", value: "cn.com")],
        sans: [LabeledValue(label: "DNS Name", value: "san.com")]
    )
    #expect(cert.hostPatterns == ["san.com"])
}

@Test
func isSelfIssuedDetection() {
    let fields = [
        LabeledValue(label: "Common Name", value: "Self CA"),
        LabeledValue(label: "Organization", value: "Self Org")
    ]
    let cert = makeCert(subject: fields, issuer: fields)
    #expect(cert.isSelfIssued == true)
}

@Test
func notSelfIssuedWhenFieldsDiffer() {
    let cert = makeCert(
        subject: [LabeledValue(label: "Common Name", value: "Leaf")],
        issuer: [LabeledValue(label: "Common Name", value: "CA")]
    )
    #expect(cert.isSelfIssued == false)
}

@Test
func notSelfIssuedWhenFieldCountDiffers() {
    let cert = makeCert(
        subject: [LabeledValue(label: "Common Name", value: "X")],
        issuer: [
            LabeledValue(label: "Common Name", value: "X"),
            LabeledValue(label: "Organization", value: "Y")
        ]
    )
    #expect(cert.isSelfIssued == false)
}

@Test
func trustBadgeTextForTrusted() {
    let trust = TrustSummary(evaluated: true, isTrusted: true, failureReason: nil)
    #expect(trust.badgeText == "Trusted")
}

@Test
func trustBadgeTextForFailed() {
    let trust = TrustSummary(evaluated: true, isTrusted: false, failureReason: "Expired")
    #expect(trust.badgeText == "Failed")
}

@Test
func trustBadgeTextForUnchecked() {
    let trust = TrustSummary(evaluated: false, isTrusted: false, failureReason: nil)
    #expect(trust.badgeText == "Unchecked")
}

@Test
func leafCertificateReturnsFirstInChain() {
    let cert = makeCert(title: "Leaf")
    let report = TLSInspectionReport(
        requestedURL: URL(string: "https://example.com")!,
        host: "example.com",
        networkProtocolName: nil,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        security: SecurityAssessment(findings: []),
        certificates: [cert]
    )
    #expect(report.leafCertificate?.title == "Leaf")
}

@Test
func leafCertificateIsNilForEmptyChain() {
    let report = TLSInspectionReport(
        requestedURL: URL(string: "https://example.com")!,
        host: "example.com",
        networkProtocolName: nil,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        security: SecurityAssessment(findings: []),
        certificates: []
    )
    #expect(report.leafCertificate == nil)
}

@Test
func sslLabsURLContainsHost() {
    let report = TLSInspectionReport(
        requestedURL: URL(string: "https://example.com")!,
        host: "example.com",
        networkProtocolName: nil,
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        security: SecurityAssessment(findings: []),
        certificates: []
    )
    #expect(report.sslLabsURL?.absoluteString.contains("example.com") == true)
}

// MARK: - Test Helpers

private func makeCert(
    title: String = "Test",
    subject: [LabeledValue] = [],
    issuer: [LabeledValue] = [],
    sans: [LabeledValue] = []
) -> CertificateDetails {
    CertificateDetails(
        id: UUID().uuidString,
        title: title,
        isLeaf: true,
        isRoot: false,
        subject: subject,
        issuer: issuer,
        validity: ValidityPeriod(
            notBefore: Date().addingTimeInterval(-3600),
            notAfter: Date().addingTimeInterval(3600)
        ),
        serialNumber: "01",
        version: "3",
        signatureAlgorithm: "sha256WithRSAEncryption",
        signature: "aa:bb",
        publicKey: PublicKeyDetails(
            algorithm: "RSA",
            bitSize: 2048,
            hexRepresentation: "00",
            spkiSHA256Fingerprint: "abc123"
        ),
        keyUsage: [],
        extendedKeyUsage: [],
        fingerprints: [],
        subjectAlternativeNames: sans,
        policies: [],
        subjectKeyIdentifier: nil,
        authorityKeyIdentifier: [],
        authorityInfoAccess: [],
        basicConstraints: [],
        extensions: [],
        derData: Data()
    )
}
