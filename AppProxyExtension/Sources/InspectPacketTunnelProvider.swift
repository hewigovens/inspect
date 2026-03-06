import InspectCore
import NetworkExtension
import OSLog

final class InspectPacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {
    private let logger = Logger(subsystem: "in.fourplex.Inspect", category: "PacketTunnelProviderWrapper")
    private lazy var runtime = makeRuntime()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        log(
            "InspectPacketTunnelProvider.startTunnel bundle=\(Bundle.main.bundleIdentifier ?? "nil") appGroup=\(InspectSharedContainer.appGroupIdentifier) engine=\(selectedForwardingEngine.rawValue)"
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
        switch selectedForwardingEngine {
        case .rust:
            log("Selected forwarding engine: rust")
            return InspectPacketTunnelRuntime(
                provider: self,
                makeOutboundConnection: makeOutboundConnection,
                makeForwardingEngine: { logger, _ in
                    RustTunnelForwardingEngine(logger: logger)
                }
            )
        case .tun2socks:
            log("Selected forwarding engine: tun2socks")
            return InspectPacketTunnelRuntime(
                provider: self,
                makeOutboundConnection: makeOutboundConnection
            )
        }
    }

    private var selectedForwardingEngine: ForwardingEngineSelection {
        if let value = ProcessInfo.processInfo.environment["INSPECT_TUNNEL_FORWARDING_ENGINE"] {
            return ForwardingEngineSelection(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .rust
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "InspectTunnelForwardingEngine") as? String {
            return ForwardingEngineSelection(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .rust
        }

        return .rust
    }

    private func makeOutboundConnection(
        host: String,
        port: UInt16,
        stateHandler: @escaping @Sendable (ConnectProxyOutboundConnection.State, Error?) -> Void
    ) -> ConnectProxyOutboundConnection? {
        log("Creating outbound provider TCP connection to \(host):\(port)")
        let endpoint = __NWHostEndpoint(hostname: host, port: String(port))
        let connection = __createTCPConnection(
            to: endpoint,
            enableTLS: false,
            tlsParameters: nil,
            delegate: nil
        )

        let stateObservation = connection.observe(\.state, options: [.initial, .new]) { [weak self] connection, _ in
            let error = connection.error
            self?.log(
                "Provider outbound state target=\(host):\(port) state=\(String(describing: connection.state)) error=\(error?.localizedDescription ?? "nil")"
            )

            switch connection.state {
            case .invalid:
                stateHandler(.failed, error)
            case .connecting:
                stateHandler(.connecting, nil)
            case .waiting:
                stateHandler(.waiting, error)
            case .connected:
                stateHandler(.ready, nil)
            case .disconnected:
                if error != nil {
                    stateHandler(.failed, error)
                } else {
                    stateHandler(.closed, nil)
                }
            case .cancelled:
                stateHandler(.cancelled, nil)
            @unknown default:
                stateHandler(.failed, error)
            }
        }

        return ConnectProxyOutboundConnection(
            readHandler: { minimumLength, maximumLength, completion in
                connection.readMinimumLength(minimumLength, maximumLength: maximumLength) { data, error in
                    completion(data, error)
                }
            },
            writeHandler: { data, completion in
                connection.write(data) { error in
                    completion(error)
                }
            },
            cancelHandler: {
                stateObservation.invalidate()
                connection.cancel()
            }
        )
    }
}

private enum ForwardingEngineSelection: String {
    case rust
    case tun2socks
}
