import Foundation
import NetworkExtension

struct InspectPacketTunnelConfiguration: Equatable, Sendable {
    static let liveMonitor = InspectPacketTunnelConfiguration(
        ipv4Address: "198.18.0.1",
        ipv4SubnetMask: "255.255.255.0",
        ipv6Address: "fd00::1",
        ipv6PrefixLength: 64,
        dnsServers: ["1.1.1.1", "8.8.8.8"],
        fakeIPAddressRange: "198.19.0.0/16",
        mtu: 1500
    )

    let ipv4Address: String
    let ipv4SubnetMask: String
    let ipv6Address: String
    let ipv6PrefixLength: Int
    let dnsServers: [String]
    let fakeIPAddressRange: String
    let mtu: Int

    var primaryDNSAddress: String {
        dnsServers.first ?? "1.1.1.1"
    }

    func makeNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: ipv4Address)
        settings.mtu = NSNumber(value: mtu)

        let ipv4Settings = NEIPv4Settings(addresses: [ipv4Address], subnetMasks: [ipv4SubnetMask])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4Settings

        let ipv6Settings = NEIPv6Settings(addresses: [ipv6Address], networkPrefixLengths: [NSNumber(value: ipv6PrefixLength)])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6Settings

        let dnsSettings = NEDNSSettings(servers: dnsServers)
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings

        return settings
    }

    func makeForwardingConfiguration(
        tunFileDescriptor: Int32,
        monitorEnabled: Bool
    ) -> InspectTunnelForwardingConfiguration {
        InspectTunnelForwardingConfiguration(
            tunFileDescriptor: tunFileDescriptor,
            ipv4Address: ipv4Address,
            ipv6Address: ipv6Address,
            dnsAddress: primaryDNSAddress,
            fakeIPAddressRange: fakeIPAddressRange,
            mtu: mtu,
            monitorEnabled: monitorEnabled
        )
    }

    func logDescription(engineName: String) -> String {
        "Applying tunnel settings: mtu=\(mtu) ipv4=\(ipv4Address) ipv6=\(ipv6Address) dns=\(dnsServers.joined(separator: ",")) engine=\(engineName)"
    }
}
