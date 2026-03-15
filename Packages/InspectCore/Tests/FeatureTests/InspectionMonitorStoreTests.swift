@testable import InspectKit
import Foundation
import InspectCore
import Testing

@MainActor
@Test
func monitoredHostsCollapseCaseAndKeepLatestReport() {
    let defaults = makeUserDefaults(suiteName: #function)
    let store = InspectionMonitorStore(
        flowObservationFeed: nil,
        enableNetworkFeedPolling: false,
        userDefaults: defaults
    )
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
    let defaults = makeUserDefaults(suiteName: #function)
    let store = InspectionMonitorStore(
        flowObservationFeed: nil,
        enableNetworkFeedPolling: false,
        userDefaults: defaults
    )
    store.setEnabled(true)

    store.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "aa"))
    store.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "bb"))

    #expect(store.entries.count == 2)
    #expect(store.entries.first?.note == "Leaf certificate fingerprint changed since the previous probe.")
}

@MainActor
@Test
func monitoredHostsRemainDistinctAcrossDifferentHosts() {
    let defaults = makeUserDefaults(suiteName: #function)
    let store = InspectionMonitorStore(
        flowObservationFeed: nil,
        enableNetworkFeedPolling: false,
        userDefaults: defaults
    )
    store.setEnabled(true)

    store.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "aa"))
    store.recordInspection(makeReport(host: "api.example.com", issuer: "CA 2", fingerprint: "bb"))

    let hosts = store.monitoredHosts.map(\.host)
    #expect(hosts.count == 2)
    #expect(hosts == ["api.example.com", "example.com"])
}

@MainActor
@Test
func monitorEntriesPersistAcrossStoreInstances() {
    let defaults = makeUserDefaults(suiteName: #function)

    let firstStore = InspectionMonitorStore(
        flowObservationFeed: nil,
        enableNetworkFeedPolling: false,
        userDefaults: defaults
    )
    firstStore.setEnabled(true)
    firstStore.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "aa"))

    let secondStore = InspectionMonitorStore(
        flowObservationFeed: nil,
        enableNetworkFeedPolling: false,
        userDefaults: defaults
    )

    #expect(secondStore.hostCount == 1)
    #expect(secondStore.monitoredHosts.first?.host == "example.com")
    #expect(secondStore.latestCapturedReport(forHost: "example.com")?.leafCertificate?.issuerSummary == "CA 1")
}

@MainActor
@Test
func monitoredHostsExposeStableActivitySummary() {
    let defaults = makeUserDefaults(suiteName: #function)
    let store = InspectionMonitorStore(
        flowObservationFeed: nil,
        enableNetworkFeedPolling: false,
        userDefaults: defaults
    )
    store.setEnabled(true)

    store.recordInspection(makeReport(host: "example.com", issuer: "CA 1", fingerprint: "aa"))
    store.recordInspection(makeReport(host: "example.com", issuer: "CA 2", fingerprint: "bb"))

    let host = store.monitoredHosts.first
    #expect(host?.statusTitle == "Trusted")
    #expect(host?.certificateAvailability == .captured)
    #expect(host?.firstSeenAt ?? .distantFuture <= host?.lastSeenAt ?? .distantPast)
}

@MainActor
@Test
func monitoredHostsHideRawProbeFailureLanguage() async throws {
    let defaults = makeUserDefaults(suiteName: #function)
    let monitorEngine = TLSMonitorProbeEngine(
        inspectionClient: FailingTLSInspectionClient()
    )
    let store = InspectionMonitorStore(
        monitorEngine: monitorEngine,
        flowObservationFeed: nil,
        enableNetworkFeedPolling: false,
        userDefaults: defaults
    )
    store.setEnabled(true)

    await store.probeHost("example.com")

    let host = try #require(store.monitoredHosts.first)
    #expect(host.statusTitle == "Seen")
    #expect(host.certificateAvailability == .pending)
    #expect(host.subtitle.contains("Awaiting certificate capture"))
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

private func makeUserDefaults(suiteName: String) -> UserDefaults {
    let suite = "InspectionMonitorStoreTests.\(suiteName)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private struct FailingTLSInspectionClient: TLSInspectionClient {
    func inspect(url: URL) async throws -> TLSInspectionReport {
        throw URLError(.cannotConnectToHost)
    }
}
