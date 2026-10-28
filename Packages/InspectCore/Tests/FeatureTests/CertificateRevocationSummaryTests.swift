@testable import InspectKit
import Foundation
import InspectCore
import Testing

@Test
func leafCertificateShowsSuccessfulRevocationCopy() {
    let summary = CertificateRevocationSummary.make(
        host: "example.com",
        status: .good
    )

    #expect(summary.title == "Not revoked")
    #expect(summary.detail == "OCSP / CRL passed for the server certificate.")
    #expect(summary.showsProgress == false)
}

@Test
func crlOnlyIssuerShowsDedicatedCopy() {
    let summary = CertificateRevocationSummary.make(
        host: "example.com",
        status: .crlOnly
    )

    #expect(summary.title == "CRL-only issuer")
    #expect(summary.detail?.contains("CRL distribution points") == true)
}

@Test
func inconclusiveRevocationNormalizesPlatformPinningErrors() {
    let summary = CertificateRevocationSummary.make(
        host: "example.com",
        status: .unreachable("Trust evaluation failed because the certificate does not meet pinning requirements.")
    )

    #expect(summary.title == "Inconclusive")
    #expect(summary.detail?.contains("did not satisfy the platform trust requirements") == true)
}

@Test
func checkingStateShowsProgressWithoutManualAction() {
    let summary = CertificateRevocationSummary.make(
        host: "example.com",
        status: .unchecked
    )

    #expect(summary.title == "Checking revocation…")
    #expect(summary.showsProgress == true)
}
