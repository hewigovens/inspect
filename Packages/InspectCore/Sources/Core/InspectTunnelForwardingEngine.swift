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
    public let dnsAddress: String
    public let fakeIPAddressRange: String
    public let mtu: Int
    public let monitorEnabled: Bool

    public init(
        tunFileDescriptor: Int32,
        ipv4Address: String,
        ipv6Address: String,
        dnsAddress: String,
        fakeIPAddressRange: String,
        mtu: Int,
        monitorEnabled: Bool
    ) {
        self.tunFileDescriptor = tunFileDescriptor
        self.ipv4Address = ipv4Address
        self.ipv6Address = ipv6Address
        self.dnsAddress = dnsAddress
        self.fakeIPAddressRange = fakeIPAddressRange
        self.mtu = mtu
        self.monitorEnabled = monitorEnabled
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
    func drainObservations() -> [TLSFlowObservation] { [] }
}
