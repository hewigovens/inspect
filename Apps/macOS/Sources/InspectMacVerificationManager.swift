import Foundation
@preconcurrency import NetworkExtension
import Observation

@MainActor
@Observable
final class InspectMacVerificationManager {
    static let providerBundleIdentifier = InspectMacTunnelDefaults.providerBundleIdentifier

    var status: NEVPNStatus = .invalid
    var isConfigured = false
    var lastErrorMessage: String?
    var actionMessage: String?

    @ObservationIgnored
    var manager: NETunnelProviderManager?
    @ObservationIgnored
    let tunnelService = InspectMacTunnelManagerService(
        profile: InspectMacTunnelDefaults.verificationProfile
    )
    @ObservationIgnored
    let observationBridge = InspectMacTunnelObservationBridge()
    @ObservationIgnored
    let diagnostics = InspectMacVerificationDiagnostics()
}
