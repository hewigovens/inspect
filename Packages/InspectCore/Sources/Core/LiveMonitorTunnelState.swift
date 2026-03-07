import NetworkExtension

public enum LiveMonitorTunnelAction: Sendable, Equatable {
    case start
    case stop
    case waitForDisconnect
    case none
}

public enum LiveMonitorTunnelState {
    public static func isActive(for status: NEVPNStatus) -> Bool {
        switch status {
        case .connected, .connecting, .reasserting:
            return true
        case .invalid, .disconnected, .disconnecting:
            return false
        @unknown default:
            return false
        }
    }

    public static func action(for status: NEVPNStatus, desiredEnabled: Bool) -> LiveMonitorTunnelAction {
        if desiredEnabled {
            switch status {
            case .connected, .connecting, .reasserting:
                return .none
            case .disconnecting:
                return .waitForDisconnect
            case .disconnected, .invalid:
                return .start
            @unknown default:
                return .none
            }
        }

        switch status {
        case .connected, .connecting, .reasserting:
            return .stop
        case .disconnecting:
            return .waitForDisconnect
        case .disconnected, .invalid:
            return .none
        @unknown default:
            return .none
        }
    }
}
