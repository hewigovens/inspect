@testable import InspectCore
import NetworkExtension
import Testing

@Test
func liveMonitorTunnelConfigurationUsesExpectedDefaults() {
    let configuration = InspectPacketTunnelConfiguration.liveMonitor

    #expect(configuration.ipv4Address == "198.18.0.1")
    #expect(configuration.ipv6Address == "fd00::1")
    #expect(configuration.dnsServers == ["1.1.1.1", "8.8.8.8"])
    #expect(configuration.fakeIPAddressRange == "198.19.0.0/16")
    #expect(configuration.mtu == 1500)
}

@Test
func liveMonitorTunnelConfigurationBuildsExpectedForwardingConfig() {
    let configuration = InspectPacketTunnelConfiguration.liveMonitor
    let forwarding = configuration.makeForwardingConfiguration(
        tunFileDescriptor: 42,
        monitorEnabled: true
    )

    #expect(forwarding.tunFileDescriptor == 42)
    #expect(forwarding.ipv4Address == "198.18.0.1")
    #expect(forwarding.ipv6Address == "fd00::1")
    #expect(forwarding.dnsAddress == "1.1.1.1")
    #expect(forwarding.fakeIPAddressRange == "198.19.0.0/16")
    #expect(forwarding.mtu == 1500)
    #expect(forwarding.monitorEnabled)
}

@Test
func liveMonitorTunnelConfigurationBuildsDefaultRouteNetworkSettings() throws {
    let configuration = InspectPacketTunnelConfiguration.liveMonitor
    let settings = configuration.makeNetworkSettings()

    #expect(settings.tunnelRemoteAddress == "198.18.0.1")
    #expect(settings.mtu?.intValue == 1500)
    #expect(settings.ipv4Settings?.addresses == ["198.18.0.1"])
    #expect(settings.ipv6Settings?.addresses == ["fd00::1"])
    #expect(settings.dnsSettings?.servers == ["1.1.1.1", "8.8.8.8"])
    #expect(settings.dnsSettings?.matchDomains == [""])
    #expect(settings.ipv4Settings?.includedRoutes?.count == 1)
    #expect(settings.ipv6Settings?.includedRoutes?.count == 1)
}
