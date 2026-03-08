import InspectCore
import NetworkExtension
import Testing

@Test(arguments: [
    (NEVPNStatus.connected, true),
    (NEVPNStatus.connecting, true),
    (NEVPNStatus.reasserting, true),
    (NEVPNStatus.disconnected, false),
    (NEVPNStatus.disconnecting, false),
    (NEVPNStatus.invalid, false)
])
func liveMonitorTunnelStateActiveFlagMatchesVPNStatus(status: NEVPNStatus, expected: Bool) {
    #expect(LiveMonitorTunnelState.isActive(for: status) == expected)
}

@Test(arguments: [
    (NEVPNStatus.disconnected, true, LiveMonitorTunnelAction.start),
    (NEVPNStatus.invalid, true, LiveMonitorTunnelAction.start),
    (NEVPNStatus.disconnecting, true, LiveMonitorTunnelAction.waitForDisconnect),
    (NEVPNStatus.connected, true, LiveMonitorTunnelAction.none),
    (NEVPNStatus.connecting, false, LiveMonitorTunnelAction.stop),
    (NEVPNStatus.reasserting, false, LiveMonitorTunnelAction.stop),
    (NEVPNStatus.disconnecting, false, LiveMonitorTunnelAction.waitForDisconnect),
    (NEVPNStatus.disconnected, false, LiveMonitorTunnelAction.none)
])
func liveMonitorTunnelStateChoosesExpectedAction(
    status: NEVPNStatus,
    desiredEnabled: Bool,
    expected: LiveMonitorTunnelAction
) {
    #expect(LiveMonitorTunnelState.action(for: status, desiredEnabled: desiredEnabled) == expected)
}
