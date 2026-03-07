import InspectCore
import NetworkExtension
import OSLog

final class InspectPacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {
    private let logger = Logger(subsystem: "in.fourplex.Inspect", category: "PacketTunnelExtension")
    private lazy var runtime = makeRuntime()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        log(
            "InspectPacketTunnelProvider.startTunnel bundle=\(Bundle.main.bundleIdentifier ?? "nil") appGroup=\(InspectSharedContainer.appGroupIdentifier) engine=rust"
        )
        runtime.startTunnel(options: options, completionHandler: completionHandler)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        log("InspectPacketTunnelProvider.stopTunnel reason=\(reason.rawValue)")
        runtime.stopTunnel(with: reason, completionHandler: completionHandler)
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        NSLog("[InspectProvider] %@", message)
        InspectSharedLog.append(scope: "InspectProvider", message: message)
    }

    private func makeRuntime() -> InspectPacketTunnelRuntime {
        log("Selected forwarding engine: rust")
        return InspectPacketTunnelRuntime(
            provider: self,
            forwardingEngine: RustTunnelForwardingEngine(logger: logger)
        )
    }
}
