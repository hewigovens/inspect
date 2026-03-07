import Foundation

public protocol TLSInspectionClient: Sendable {
    func inspect(url: URL) async throws -> TLSInspectionReport
}

public struct LiveTLSInspectionClient: TLSInspectionClient {
    public init() {}

    public func inspect(url: URL) async throws -> TLSInspectionReport {
        try await TLSInspector().inspect(url: url)
    }
}

public struct TLSMonitorProbeConfiguration: Sendable, Equatable {
    public var minimumProbeInterval: TimeInterval
    public var defaultHTTPSPort: Int

    public init(minimumProbeInterval: TimeInterval = 45, defaultHTTPSPort: Int = 443) {
        self.minimumProbeInterval = minimumProbeInterval
        self.defaultHTTPSPort = defaultHTTPSPort
    }
}

public actor TLSMonitorProbeEngine {
    private let configuration: TLSMonitorProbeConfiguration
    private let inspectionClient: any TLSInspectionClient
    private let passiveReportBuilder: PassiveTLSInspectionReportBuilder
    private let now: @Sendable () -> Date
    private var nextAllowedProbeByHost: [String: Date] = [:]

    public init(
        configuration: TLSMonitorProbeConfiguration = TLSMonitorProbeConfiguration(),
        inspectionClient: any TLSInspectionClient = LiveTLSInspectionClient(),
        passiveReportBuilder: PassiveTLSInspectionReportBuilder = PassiveTLSInspectionReportBuilder(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.inspectionClient = inspectionClient
        self.passiveReportBuilder = passiveReportBuilder
        self.now = now
    }

    public func handle(_ observation: TLSFlowObservation) async -> TLSProbeEvent {
        let timestamp = now()

        if let report = passiveReportBuilder.build(from: observation) {
            if let host = observation.passiveInspectionHost {
                nextAllowedProbeByHost[host] = timestamp.addingTimeInterval(configuration.minimumProbeInterval)
            }

            return TLSProbeEvent(
                observation: observation,
                occurredAt: timestamp,
                result: .captured(report)
            )
        }

        guard let host = observation.probeHost else {
            return TLSProbeEvent(
                observation: observation,
                occurredAt: timestamp,
                result: .skippedMissingHost
            )
        }

        if let nextAllowed = nextAllowedProbeByHost[host], timestamp < nextAllowed {
            return TLSProbeEvent(
                observation: observation,
                occurredAt: timestamp,
                result: .skippedThrottled(until: nextAllowed)
            )
        }

        nextAllowedProbeByHost[host] = timestamp.addingTimeInterval(configuration.minimumProbeInterval)

        guard let url = observation.probeURL(defaultHTTPSPort: configuration.defaultHTTPSPort) else {
            return TLSProbeEvent(
                observation: observation,
                occurredAt: timestamp,
                result: .failed(reason: "Unable to build probe URL from flow observation.")
            )
        }

        do {
            let report = try await inspectionClient.inspect(url: url)
            return TLSProbeEvent(
                observation: observation,
                occurredAt: timestamp,
                result: .captured(report)
            )
        } catch {
            return TLSProbeEvent(
                observation: observation,
                occurredAt: timestamp,
                result: .failed(reason: error.localizedDescription)
            )
        }
    }

    public func resetThrottleWindow() {
        nextAllowedProbeByHost.removeAll()
    }
}
