@testable import InspectFeature
import Foundation
import InspectCore
import Testing

@MainActor
@Test
func monitoredHostsCollapseCaseAndKeepLatestReport() {
    let store = InspectionMonitorStore(flowObservationFeed: nil, enableNetworkFeedPolling: false)
    store.setEnabled(true)

    store.recordInspection(makeReport(host: "Example.com", issuer: "CA 1", fingerprint: "aa"))
    store.recordInspection(makeReport(host: "example.com", issuer: "CA 2", fingerprint: "bb"))

    let hosts = store.monitoredHosts
    #expect(store.hostCount == 1)
    #expect(hosts.count == 1)
    #expect(hosts.first?.host == "example.com")
    #expect(hosts.first?.latestReport?.leafCertificate?.issuerSummary == "CA 2")
    #expect(store.latestCapturedReport(forHost: "EXAMPLE.COM")?.leafCertificate?.issuerSummary == "CA 2")
    #expect(store.entries(forHost: "example.com").count == 2)
}

@MainActor
@Test
func recordInspectionAddsFingerprintChangeNoteForSameHost() {
    let store = InspectionMonitorStore(flowObservationFeed: nil, enableNetworkFeedPolling: false)
    store.setEnabled(true)

    store.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "aa"))
    store.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "bb"))

    #expect(store.entries.count == 2)
    #expect(store.entries.first?.note == "Leaf certificate fingerprint changed since the previous probe.")
}

@MainActor
@Test
func monitoredHostsRemainDistinctAcrossDifferentHosts() {
    let store = InspectionMonitorStore(flowObservationFeed: nil, enableNetworkFeedPolling: false)
    store.setEnabled(true)

    store.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "aa"))
    store.recordInspection(makeReport(host: "api.example.com", issuer: "CA 2", fingerprint: "bb"))

    let hosts = store.monitoredHosts.map(\.host)
    #expect(hosts.count == 2)
    #expect(hosts == ["api.example.com", "example.com"])
}

private func makeReport(host: String, issuer: String, fingerprint: String) -> TLSInspectionReport {
    let normalizedHost = host.lowercased()
    return TLSInspectionReport(
        requestedURL: URL(string: "https://\(normalizedHost)")!,
        host: host,
        networkProtocolName: "h2",
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        security: SecurityAssessment(findings: []),
        certificates: [
            CertificateDetails(
                id: "\(normalizedHost)-leaf",
                title: normalizedHost,
                isLeaf: true,
                isRoot: false,
                subject: [LabeledValue(label: "Common Name", value: normalizedHost)],
                issuer: [LabeledValue(label: "Common Name", value: issuer)],
                validity: ValidityPeriod(notBefore: nil, notAfter: nil),
                serialNumber: "01",
                version: "3",
                signatureAlgorithm: "sha256WithRSAEncryption",
                signature: "00",
                publicKey: PublicKeyDetails(
                    algorithm: "RSA",
                    bitSize: 2048,
                    hexRepresentation: "00",
                    spkiSHA256Fingerprint: fingerprint
                ),
                keyUsage: [],
                extendedKeyUsage: [],
                fingerprints: [LabeledValue(label: "SHA-256", value: fingerprint)],
                subjectAlternativeNames: [LabeledValue(label: "DNS Name", value: normalizedHost)],
                policies: [],
                subjectKeyIdentifier: nil,
                authorityKeyIdentifier: [],
                authorityInfoAccess: [],
                basicConstraints: [],
                extensions: [],
                derData: Data([0x01, 0x02, 0x03])
            )
        ]
    )
}
