import Foundation
import InspectCore
import SwiftUI

@MainActor
enum InspectionScreenshotFixtures {
    static let featuredReport = makeReport(
        host: "github.com",
        networkProtocolName: "h2",
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        findings: [
            SecurityFinding(
                severity: .good,
                title: "Trusted Chain",
                message: "The captured chain validated successfully."
            )
        ],
        certificates: [
            makeCertificate(
                host: "github.com",
                title: "github.com",
                issuer: "Sectigo ECC Domain Validation Secure Server CA",
                fingerprint: "AA:BB:CC:DD",
                isLeaf: true,
                isRoot: false
            ),
            makeCertificate(
                host: "sectigo-intermediate",
                title: "Sectigo ECC Domain Validation Secure Server CA",
                issuer: "USERTrust ECC Certification Authority",
                fingerprint: "11:22:33:44",
                isLeaf: false,
                isRoot: false
            ),
            makeCertificate(
                host: "usertrust-root",
                title: "USERTrust ECC Certification Authority",
                issuer: "USERTrust ECC Certification Authority",
                fingerprint: "55:66:77:88",
                isLeaf: false,
                isRoot: true
            )
        ]
    )

    static let secondaryReport = makeReport(
        host: "api.stripe.com",
        networkProtocolName: "h2",
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        findings: [],
        certificates: [
            makeCertificate(
                host: "api.stripe.com",
                title: "api.stripe.com",
                issuer: "Amazon RSA 2048 M02",
                fingerprint: "99:AA:BB:CC",
                isLeaf: true,
                isRoot: false
            )
        ]
    )

    static func makeMonitorStore() -> InspectionMonitorStore {
        let suiteName = "InspectionScreenshotFixtures.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = InspectionMonitorStore(
            flowObservationFeed: nil,
            enableNetworkFeedPolling: false,
            userDefaults: defaults
        )
        store.setEnabled(true)
        store.recordInspection(featuredReport)
        store.recordInspection(secondaryReport)
        return store
    }

    private static func makeReport(
        host: String,
        networkProtocolName: String,
        trust: TrustSummary,
        findings: [SecurityFinding],
        certificates: [CertificateDetails]
    ) -> TLSInspectionReport {
        TLSInspectionReport(
            requestedURL: URL(string: "https://\(host)")!,
            host: host,
            networkProtocolName: networkProtocolName,
            trust: trust,
            security: SecurityAssessment(findings: findings),
            certificates: certificates
        )
    }

    private static func makeCertificate(
        host: String,
        title: String,
        issuer: String,
        fingerprint: String,
        isLeaf: Bool,
        isRoot: Bool
    ) -> CertificateDetails {
        CertificateDetails(
            id: "\(host)-\(title)",
            title: title,
            isLeaf: isLeaf,
            isRoot: isRoot,
            subject: [LabeledValue(label: "Common Name", value: title)],
            issuer: [LabeledValue(label: "Common Name", value: issuer)],
            validity: ValidityPeriod(
                notBefore: Calendar.current.date(byAdding: .day, value: -30, to: .now),
                notAfter: Calendar.current.date(byAdding: .day, value: 335, to: .now)
            ),
            serialNumber: "01",
            version: "3",
            signatureAlgorithm: "ecdsa-with-SHA256",
            signature: "00",
            publicKey: PublicKeyDetails(
                algorithm: "EC",
                bitSize: 256,
                hexRepresentation: "00",
                spkiSHA256Fingerprint: fingerprint
            ),
            keyUsage: ["Digital Signature", "Key Encipherment"],
            extendedKeyUsage: ["Server Authentication"],
            fingerprints: [LabeledValue(label: "SHA-256", value: fingerprint)],
            subjectAlternativeNames: [LabeledValue(label: "DNS Name", value: host)],
            policies: [LabeledValue(label: "Policy", value: "DV")],
            subjectKeyIdentifier: "AB:CD:EF",
            authorityKeyIdentifier: [LabeledValue(label: "Key Identifier", value: "12:34:56")],
            authorityInfoAccess: [LabeledValue(label: "OCSP", value: "http://ocsp.example.test")],
            basicConstraints: [LabeledValue(label: "CA", value: isLeaf ? "No" : "Yes")],
            sctList: [],
            crlDistributionPoints: [],
            extensions: [],
            derData: Data([0x01, 0x02, 0x03, 0x04])
        )
    }
}
