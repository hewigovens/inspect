import InspectCore
import NetworkExtension

final class InspectPacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {
    private let logger = InspectRuntimeLogger(
        category: "PacketTunnelExtension",
        scope: "InspectProvider"
    )
    private lazy var runtime = makeRuntime()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.verbose(
            "InspectPacketTunnelProvider.startTunnel bundle=\(Bundle.main.bundleIdentifier ?? "nil") appGroup=\(InspectSharedContainer.appGroupIdentifier) engine=tunnel-core"
        )
        runtime.startTunnel(options: options, completionHandler: completionHandler)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.verbose("InspectPacketTunnelProvider.stopTunnel reason=\(reason.rawValue)")
        runtime.stopTunnel(with: reason, completionHandler: completionHandler)
    }

    private func makeRuntime() -> InspectPacketTunnelRuntime {
        logger.verbose("Selected forwarding engine: tunnel-core")
        return InspectPacketTunnelRuntime(
            provider: self,
            forwardingEngine: TunnelForwardingEngine(
                logger: InspectRuntimeLogger(
                    category: "PacketTunnelExtension",
                    scope: "InspectTunnelCore"
                )
            )
        )
    }
}
