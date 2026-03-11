import Foundation

struct InspectMacTunnelProfile: Sendable {
    let localizedDescription: String
    let serverAddress: String
    let providerBundleIdentifier: String
}

enum InspectMacTunnelDefaults {
    static let providerBundleIdentifier = "in.fourplex.Inspect.PacketTunnelExtension"

    static let verificationProfile = InspectMacTunnelProfile(
        localizedDescription: "Inspect Live Monitor",
        serverAddress: "Inspect Live Monitor",
        providerBundleIdentifier: providerBundleIdentifier
    )

    static let smokeTestProfile = InspectMacTunnelProfile(
        localizedDescription: "Inspect Live Monitor (Mac Smoke Test)",
        serverAddress: "Inspect macOS Smoke Test",
        providerBundleIdentifier: providerBundleIdentifier
    )
}
