import Foundation

public enum TLSFlowSource: String, Sendable, Codable, CaseIterable {
    case manualInspection
    case networkExtension
    case simulation
}

public enum TLSFlowTransport: String, Sendable, Codable {
    case tcp
    case udp
    case unknown
}

public struct TLSFlowObservation: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let observedAt: Date
    public let source: TLSFlowSource
    public let transport: TLSFlowTransport
    public let remoteHost: String?
    public let remotePort: Int?
    public let serverName: String?
    public let negotiatedProtocol: String?
    public let sourceAppIdentifier: String?
    public let capturedCertificateChainDER: [Data]?

    public init(
        id: UUID = UUID(),
        observedAt: Date = Date(),
        source: TLSFlowSource,
        transport: TLSFlowTransport = .tcp,
        remoteHost: String?,
        remotePort: Int? = nil,
        serverName: String? = nil,
        negotiatedProtocol: String? = nil,
        sourceAppIdentifier: String? = nil,
        capturedCertificateChainDER: [Data]? = nil
    ) {
        self.id = id
        self.observedAt = observedAt
        self.source = source
        self.transport = transport
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.serverName = serverName
        self.negotiatedProtocol = negotiatedProtocol
        self.sourceAppIdentifier = sourceAppIdentifier
        self.capturedCertificateChainDER = capturedCertificateChainDER
    }

    public var probeHost: String? {
        normalizedHostExcludingIPs(serverName) ?? normalizedHostExcludingIPs(remoteHost)
    }

    public var passiveInspectionHost: String? {
        HostNormalizer.normalized(serverName) ?? HostNormalizer.normalized(remoteHost)
    }

    public func probeURL(defaultHTTPSPort: Int = 443) -> URL? {
        guard let probeHost else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = probeHost

        if let remotePort, remotePort > 0, remotePort != defaultHTTPSPort {
            components.port = remotePort
        }

        return components.url
    }

    private func normalizedHostExcludingIPs(_ candidate: String?) -> String? {
        guard let normalized = HostNormalizer.normalized(candidate) else {
            return nil
        }

        guard HostNormalizer.isIPAddressLiteral(normalized) == false else {
            return nil
        }

        return normalized
    }
}

public enum TLSProbeResult: Sendable, Equatable, Codable {
    case captured(TLSInspectionReport)
    case skippedMissingHost
    case skippedThrottled(until: Date)
    case failed(reason: String)
}

public struct TLSProbeEvent: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let observation: TLSFlowObservation
    public let occurredAt: Date
    public let result: TLSProbeResult

    public init(
        id: UUID = UUID(),
        observation: TLSFlowObservation,
        occurredAt: Date = Date(),
        result: TLSProbeResult
    ) {
        self.id = id
        self.observation = observation
        self.occurredAt = occurredAt
        self.result = result
    }
}
