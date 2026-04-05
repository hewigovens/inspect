@testable import InspectCore
import Foundation
import Testing

@Test
func revocationFallbackReturnsCRLOnlyWhenLeafLacksOCSPButHasCRLDistributionPoint() {
    let status = RevocationChecker.fallbackStatus(
        for: makeCertificate(
            authorityInfoAccess: [],
            crlDistributionPoints: [LabeledValue(label: "Distribution Point #1", value: "http://crl.example.test/ca.crl")]
        ),
        errorMessage: "A positive response was not received."
    )

    #expect(status == .crlOnly)
}

@Test
func revocationFallbackReturnsUnreachableForOCSPFailuresWhenNoCRLOnlyPatternExists() {
    let status = RevocationChecker.fallbackStatus(
        for: makeCertificate(
            authorityInfoAccess: [LabeledValue(label: "OCSP Server", value: "http://ocsp.example.test")],
            crlDistributionPoints: []
        ),
        errorMessage: "The OCSP responder could not be contacted."
    )

    #expect(status == .unreachable("The OCSP responder could not be contacted."))
}

@Test
func revocationFallbackReturnsNilForNonRevocationErrors() {
    let status = RevocationChecker.fallbackStatus(
        for: makeCertificate(
            authorityInfoAccess: [LabeledValue(label: "CA Issuers", value: "http://ca.example.test/issuer.der")],
            crlDistributionPoints: []
        ),
        errorMessage: "Evaluation failed"
    )

    #expect(status == nil)
}

private func makeCertificate(
    authorityInfoAccess: [LabeledValue],
    crlDistributionPoints: [LabeledValue]
) -> CertificateDetails {
    CertificateDetails(
        id: UUID().uuidString,
        title: "example.com",
        isLeaf: true,
        isRoot: false,
        subject: [LabeledValue(label: "Common Name", value: "example.com")],
        issuer: [LabeledValue(label: "Common Name", value: "Example CA")],
        validity: ValidityPeriod(notBefore: nil, notAfter: nil),
        serialNumber: "01",
        version: "3",
        signatureAlgorithm: "sha256WithRSAEncryption",
        signature: "00",
        publicKey: PublicKeyDetails(
            algorithm: "RSA",
            bitSize: 2048,
            hexRepresentation: "00",
            spkiSHA256Fingerprint: "abc123"
        ),
        keyUsage: [],
        extendedKeyUsage: [],
        fingerprints: [],
        subjectAlternativeNames: [LabeledValue(label: "DNS Name", value: "example.com")],
        policies: [],
        subjectKeyIdentifier: nil,
        authorityKeyIdentifier: [],
        authorityInfoAccess: authorityInfoAccess,
        basicConstraints: [],
        sctList: [],
        crlDistributionPoints: crlDistributionPoints,
        extensions: [],
        derData: Data([0x01])
    )
}
