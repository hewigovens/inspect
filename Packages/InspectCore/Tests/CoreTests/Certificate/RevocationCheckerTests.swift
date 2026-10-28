@testable import InspectCore
import Foundation
import Security
import Testing

@Test
func incompleteRevocationCheckReturnsCRLOnlyWhenLeafLacksOCSP() {
    let status = RevocationChecker.failureStatus(
        for: makeCertificate(
            authorityInfoAccess: [],
            crlDistributionPoints: [LabeledValue(label: "Distribution Point #1", value: "http://crl.example.test/ca.crl")]
        ),
        error: trustError(errSecIncompleteCertRevocationCheck, message: "A positive response was not received.")
    )

    #expect(status == .crlOnly)
}

@Test
func ocspFailurePreservesItsDiagnostic() {
    let status = RevocationChecker.failureStatus(
        for: makeCertificate(
            authorityInfoAccess: [LabeledValue(label: "OCSP Server", value: "http://ocsp.example.test")],
            crlDistributionPoints: []
        ),
        error: trustError(errSecOCSPUnavailable, message: "The OCSP responder could not be contacted.")
    )

    #expect(status == .unreachable("The OCSP responder could not be contacted."))
}

@Test
func incompleteRevocationCheckRequiresCRLDistributionPoints() {
    let status = RevocationChecker.failureStatus(
        for: makeCertificate(
            authorityInfoAccess: [LabeledValue(label: "CA Issuers", value: "http://ca.example.test/issuer.der")],
            crlDistributionPoints: []
        ),
        error: trustError(errSecIncompleteCertRevocationCheck, message: "A positive response was not received.")
    )

    #expect(status == .unreachable("A positive response was not received."))
}

@Test(arguments: [errSecCertificateExpired, errSecCRLNotFound, errSecNotTrusted])
func crlOnlyCertificatesPreserveOtherEvaluationFailures(code: OSStatus) {
    let message = "Diagnostic for \(code)"
    let status = RevocationChecker.failureStatus(
        for: makeCertificate(
            authorityInfoAccess: [],
            crlDistributionPoints: [LabeledValue(label: "Distribution Point #1", value: "http://crl.example.test/ca.crl")]
        ),
        error: trustError(code, message: message)
    )

    #expect(status == .unreachable(message))
}

@Test
func incompleteRevocationCheckRequiresTheOSStatusErrorDomain() {
    let status = RevocationChecker.failureStatus(
        for: makeCertificate(
            authorityInfoAccess: [],
            crlDistributionPoints: [LabeledValue(label: "Distribution Point #1", value: "http://crl.example.test/ca.crl")]
        ),
        error: NSError(domain: "example.test", code: Int(errSecIncompleteCertRevocationCheck))
    )

    guard case .unreachable = status else {
        Issue.record("An unrelated error domain must remain inconclusive")
        return
    }
}

@Test
func revokedCertificateUsesTheErrorCodeRegardlessOfLanguage() {
    let status = RevocationChecker.failureStatus(
        for: nil,
        error: trustError(errSecCertificateRevoked, message: "証明書が失効しています。")
    )

    #expect(status == .revoked("証明書が失効しています。"))
}

@Test
func missingTrustErrorRemainsInconclusive() {
    #expect(RevocationChecker.failureStatus(for: nil, error: nil) == .unreachable("Evaluation failed"))
}

private func trustError(_ code: OSStatus, message: String) -> NSError {
    NSError(domain: NSOSStatusErrorDomain, code: Int(code), userInfo: [NSLocalizedDescriptionKey: message])
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
