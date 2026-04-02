import Foundation

public struct InspectTunnelForwardingStats: Sendable, Equatable {
    public let txPackets: Int
    public let txBytes: Int
    public let rxPackets: Int
    public let rxBytes: Int

    public init(txPackets: Int, txBytes: Int, rxPackets: Int, rxBytes: Int) {
        self.txPackets = txPackets
        self.txBytes = txBytes
        self.rxPackets = rxPackets
        self.rxBytes = rxBytes
    }
}

public struct InspectTunnelForwardingConfiguration: Sendable, Equatable {
    public let tunFileDescriptor: Int32
    public let ipv4Address: String
    public let ipv6Address: String
    public let dnsServers: [String]
    public let fakeIPAddressRange: String
    public let mtu: Int
    public let monitorEnabled: Bool
    public let logVerbosity: InspectLogVerbosity

    public var primaryDNSAddress: String {
        dnsServers.first ?? "1.1.1.1"
    }

    public init(
        tunFileDescriptor: Int32,
        ipv4Address: String,
        ipv6Address: String,
        dnsServers: [String],
        fakeIPAddressRange: String,
        mtu: Int,
        monitorEnabled: Bool,
        logVerbosity: InspectLogVerbosity
    ) {
        self.tunFileDescriptor = tunFileDescriptor
        self.ipv4Address = ipv4Address
        self.ipv6Address = ipv6Address
        self.dnsServers = dnsServers
        self.fakeIPAddressRange = fakeIPAddressRange
        self.mtu = mtu
        self.monitorEnabled = monitorEnabled
        self.logVerbosity = logVerbosity
    }
}

public protocol InspectTunnelForwardingEngine: AnyObject, Sendable {
    var displayName: String { get }

    func start(
        configuration: InspectTunnelForwardingConfiguration,
        exitHandler: @escaping @Sendable (Int32) -> Void
    ) throws
    func stop()
    func stats() -> InspectTunnelForwardingStats
    func drainObservations() -> [TLSFlowObservation]
}

public extension InspectTunnelForwardingEngine {
    func drainObservations() -> [TLSFlowObservation] {
        []
    }
}
