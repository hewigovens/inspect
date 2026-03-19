@preconcurrency import NetworkExtension

public extension NEVPNStatus {
    var inspectionDescription: String {
        switch self {
        case .invalid:
            InspectionCommonStrings.VPNStatus.invalid
        case .disconnected:
            InspectionCommonStrings.VPNStatus.disconnected
        case .connecting:
            InspectionCommonStrings.VPNStatus.connecting
        case .connected:
            InspectionCommonStrings.VPNStatus.connected
        case .reasserting:
            InspectionCommonStrings.VPNStatus.reasserting
        case .disconnecting:
            InspectionCommonStrings.VPNStatus.disconnecting
        @unknown default:
            InspectionCommonStrings.VPNStatus.unknown
        }
    }
}
