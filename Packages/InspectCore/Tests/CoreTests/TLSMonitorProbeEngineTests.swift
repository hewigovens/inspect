import Foundation
import InspectCore
import Testing

@Test
func skipsObservationWithoutHostMetadata() async throws {
    let inspector = InspectorStub(result: .success(makeReport(host: "example.com")))
    let engine = TLSMonitorProbeEngine(inspectionClient: inspector)

    let event = await engine.handle(TLSFlowObservation(source: .networkExtension, remoteHost: nil))

    #expect(event.result == .skippedMissingHost)
    #expect(await inspector.callCount() == 0)
}

@Test
func skipsObservationWhenOnlyIPAddressIsAvailable() async throws {
    let inspector = InspectorStub(result: .success(makeReport(host: "example.com")))
    let engine = TLSMonitorProbeEngine(inspectionClient: inspector)
    let observation = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "142.250.199.78",
        serverName: nil
    )

    let event = await engine.handle(observation)

    #expect(event.result == .skippedMissingHost)
    #expect(await inspector.callCount() == 0)
}

@Test
func throttlesRepeatedProbeAttemptsForSameHost() async throws {
    let inspector = InspectorStub(result: .success(makeReport(host: "example.com")))
    let timestamp = Date(timeIntervalSince1970: 1_750_000_000)
    let engine = TLSMonitorProbeEngine(
        configuration: TLSMonitorProbeConfiguration(minimumProbeInterval: 60),
        inspectionClient: inspector,
        now: { timestamp }
    )
    let observation = TLSFlowObservation(source: .networkExtension, remoteHost: "example.com")

    _ = await engine.handle(observation)
    let second = await engine.handle(observation)

    switch second.result {
    case let .skippedThrottled(until):
        #expect(until == timestamp.addingTimeInterval(60))
    case .captured, .skippedMissingHost, .failed:
        Issue.record("Expected throttled probe result for repeated host.")
    }

    #expect(await inspector.callCount() == 1)
}

@Test
func prefersSNIAndPortWhenBuildingProbeURL() async throws {
    let inspector = InspectorStub(result: .success(makeReport(host: "api.example.com")))
    let engine = TLSMonitorProbeEngine(inspectionClient: inspector)
    let observation = TLSFlowObservation(
        source: .networkExtension,
        transport: .tcp,
        remoteHost: "10.0.0.2",
        remotePort: 8443,
        serverName: "api.example.com"
    )

    _ = await engine.handle(observation)

    let url = try #require(await inspector.lastURL())
    #expect(url.scheme == "https")
    #expect(url.host == "api.example.com")
    #expect(url.port == 8443)
}

@Test
func returnsProbeFailureWhenInspectorThrows() async throws {
    let inspector = InspectorStub(result: .failure(ProbeStubError()))
    let engine = TLSMonitorProbeEngine(inspectionClient: inspector)
    let observation = TLSFlowObservation(source: .networkExtension, remoteHost: "example.com")

    let event = await engine.handle(observation)

    switch event.result {
    case let .failed(reason):
        #expect(reason.contains("Probe stub failure"))
    case .captured, .skippedMissingHost, .skippedThrottled:
        Issue.record("Expected failed probe result.")
    }
}

private actor InspectorStub: TLSInspectionClient {
    private let result: Result<TLSInspectionReport, Error>
    private var urls: [URL] = []

    init(result: Result<TLSInspectionReport, Error>) {
        self.result = result
    }

    func inspect(url: URL) async throws -> TLSInspectionReport {
        urls.append(url)
        return try result.get()
    }

    func callCount() -> Int {
        urls.count
    }

    func lastURL() -> URL? {
        urls.last
    }
}

private struct ProbeStubError: LocalizedError {
    var errorDescription: String? {
        "Probe stub failure"
    }
}

private func makeReport(host: String) -> TLSInspectionReport {
    let url = URL(string: "https://\(host)")!
    return TLSInspectionReport(
        requestedURL: url,
        host: host,
        networkProtocolName: "h2",
        trust: TrustSummary(evaluated: true, isTrusted: true, failureReason: nil),
        security: SecurityAssessment(findings: []),
        certificates: []
    )
}
