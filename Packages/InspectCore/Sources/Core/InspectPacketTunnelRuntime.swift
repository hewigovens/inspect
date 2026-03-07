import Darwin
import Foundation
import NetworkExtension
import OSLog

public final class InspectPacketTunnelRuntime: @unchecked Sendable {
    private let provider: NEPacketTunnelProvider
    private let observationFeed: TLSFlowObservationFeed
    private let logger: Logger
    private let forwardingEngine: any InspectTunnelForwardingEngine
    private let stateQueue = DispatchQueue(label: "in.fourplex.Inspect.PacketTunnel.state")
    private let tunnelConfiguration = InspectPacketTunnelConfiguration.liveMonitor

    private var isRunning = false
    private var lastObservationAtByKey: [String: Date] = [:]
    private let flowObservationThrottleInterval: TimeInterval = 12
    private let certificateObservationThrottleInterval: TimeInterval = 45
    private var diagnosticTimer: DispatchSourceTimer?
    private var observationDrainTimer: DispatchSourceTimer?
    private var loggedObservationCount = 0

    public init(
        provider: NEPacketTunnelProvider,
        observationFeed: TLSFlowObservationFeed = TLSFlowObservationFeed(),
        loggerSubsystem: String = "in.fourplex.Inspect",
        loggerCategory: String = "PacketTunnelProvider",
        forwardingEngine: any InspectTunnelForwardingEngine
    ) {
        self.provider = provider
        self.observationFeed = observationFeed
        self.logger = Logger(subsystem: loggerSubsystem, category: loggerCategory)
        self.forwardingEngine = forwardingEngine
    }

    public func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        _ = options
        InspectSharedLog.reset()
        logger.info("Starting packet tunnel provider")
        log("startTunnel called. appGroup=\(InspectSharedContainer.appGroupIdentifier)")
        let startCompletion = StartCompletionHandler(callback: completionHandler)

        let settings = tunnelConfiguration.makeNetworkSettings()
        log(tunnelConfiguration.logDescription(engineName: forwardingEngine.displayName))

        provider.setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else {
                startCompletion.callback(error)
                return
            }

            if let error {
                self.logger.error("Failed to configure packet tunnel settings: \(error.localizedDescription, privacy: .public)")
                self.log("setTunnelNetworkSettings failed: \(error.localizedDescription)")
                startCompletion.callback(error)
                return
            }
            self.log("setTunnelNetworkSettings succeeded")

            self.stateQueue.sync {
                self.isRunning = true
                self.lastObservationAtByKey.removeAll()
                self.loggedObservationCount = 0
            }

            guard let tunnelFileDescriptor = self.tunnelFileDescriptor else {
                let error = InspectPacketTunnelRuntimeError.missingTunnelFileDescriptor
                self.log("forwarding pipeline startup failed: \(error.localizedDescription)")
                startCompletion.callback(error)
                return
            }
            self.log("Detected utun file descriptor \(tunnelFileDescriptor)")

            let configuration = self.tunnelConfiguration.makeForwardingConfiguration(
                tunFileDescriptor: tunnelFileDescriptor,
                monitorEnabled: true
            )

            do {
                try self.startForwardingEngine(configuration: configuration)
                self.startObservationDrain()
                self.startDiagnosticLogging()
            } catch {
                self.logger.error("Failed to start forwarding pipeline: \(error.localizedDescription, privacy: .public)")
                self.log("forwarding pipeline startup failed: \(error.localizedDescription)")
                startCompletion.callback(error)
                return
            }

            self.log("Packet tunnel runtime started successfully")
            startCompletion.callback(nil)
        }
    }

    public func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping packet tunnel provider. reason=\(String(describing: reason.rawValue), privacy: .public)")
        log("stopTunnel called. reason=\(reason.rawValue)")

        stateQueue.sync {
            isRunning = false
            lastObservationAtByKey.removeAll()
            loggedObservationCount = 0
        }

        stopObservationDrain()
        stopDiagnosticLogging()
        stopForwardingEngine()
        completionHandler()
    }

    private func recordObservation(_ observation: TLSFlowObservation) {
        guard let endpointIdentity = observation.passiveInspectionHost ?? observation.remoteHost else {
            return
        }

        let endpointKey = observationKey(for: observation, endpointIdentity: endpointIdentity)
        let now = Date()
        let throttleInterval = observation.capturedCertificateChainDER == nil
            ? flowObservationThrottleInterval
            : certificateObservationThrottleInterval

        let shouldEmit = stateQueue.sync { () -> Bool in
            if let lastObservedAt = lastObservationAtByKey[endpointKey],
               now.timeIntervalSince(lastObservedAt) < throttleInterval {
                return false
            }

            lastObservationAtByKey[endpointKey] = now

            if lastObservationAtByKey.count > 2048 {
                let cutoff = now.addingTimeInterval(-300)
                lastObservationAtByKey = lastObservationAtByKey.filter { $0.value >= cutoff }
            }

            return true
        }

        guard shouldEmit else {
            return
        }

        let shouldLogObservation = stateQueue.sync { () -> Bool in
            loggedObservationCount += 1
            return loggedObservationCount <= 12 || loggedObservationCount.isMultiple(of: 25)
        }

        if shouldLogObservation {
            log(
                "Observed flow transport=\(observation.transport.rawValue) host=\(observation.remoteHost ?? "nil") port=\(observation.remotePort.map(String.init) ?? "nil") sni=\(observation.serverName ?? "nil") certs=\(observation.capturedCertificateChainDER?.count ?? 0)"
            )
        }

        Task {
            await observationFeed.append(observation)
        }
    }

    private func startDiagnosticLogging() {
        stopDiagnosticLogging()

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        var tick = 0
        timer.schedule(deadline: .now() + 3, repeating: 3)
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            let stats = self.forwardingEngine.stats()
            self.log(
                "\(self.forwardingEngine.displayName) stats[\(tick)] upPackets=\(stats.txPackets) upBytes=\(stats.txBytes) downPackets=\(stats.rxPackets) downBytes=\(stats.rxBytes)"
            )

            tick += 1
            if tick >= 20 {
                self.stopDiagnosticLogging()
                self.log("Forwarding engine diagnostic logging stopped after 60s")
            }
        }
        timer.resume()
        diagnosticTimer = timer
    }

    private func stopDiagnosticLogging() {
        diagnosticTimer?.cancel()
        diagnosticTimer = nil
    }

    private func startObservationDrain() {
        stopObservationDrain()

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            let observations = self.forwardingEngine.drainObservations()
            guard observations.isEmpty == false else {
                return
            }

            for observation in observations {
                self.recordObservation(observation)
            }
        }
        timer.resume()
        observationDrainTimer = timer
    }

    private func stopObservationDrain() {
        observationDrainTimer?.cancel()
        observationDrainTimer = nil
    }

    private func startForwardingEngine(configuration: InspectTunnelForwardingConfiguration) throws {
        log("Starting forwarding engine \(forwardingEngine.displayName)")
        try forwardingEngine.start(configuration: configuration) { [weak self] code in
            guard let self else {
                return
            }

            let shouldCancelTunnel = self.stateQueue.sync { self.isRunning }
            self.log("Forwarding engine \(self.forwardingEngine.displayName) exited with code \(code)")

            if shouldCancelTunnel {
                self.provider.cancelTunnelWithError(
                    InspectPacketTunnelRuntimeError.forwardingEngineExited(
                        name: self.forwardingEngine.displayName,
                        code: code
                    )
                )
            }
        }
    }

    private func stopForwardingEngine() {
        log("Stopping forwarding engine \(forwardingEngine.displayName)")
        forwardingEngine.stop()
    }

    private var tunnelFileDescriptor: Int32? {
        var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))

        for fileDescriptor: Int32 in 0...1024 {
            var length = socklen_t(buffer.count)
            let interfaceName: String
            if getsockopt(
                fileDescriptor,
                2,
                2,
                &buffer,
                &length
            ) == 0 {
                let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                interfaceName = String(decoding: bytes, as: UTF8.self)
                if interfaceName.hasPrefix("utun") {
                    return fileDescriptor
                }
            }
        }

        return nil
    }

    private func observationKey(for observation: TLSFlowObservation, endpointIdentity: String) -> String {
        if let leafCertificate = observation.capturedCertificateChainDER?.first {
            let leafPrefix = leafCertificate.prefix(8).map { String(format: "%02x", $0) }.joined()
            return "cert|\(observation.transport.rawValue)|\(endpointIdentity)|\(observation.remotePort ?? 0)|\(leafPrefix)"
        }

        return "flow|\(observation.transport.rawValue)|\(endpointIdentity)|\(observation.remotePort ?? 0)"
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        NSLog("[InspectTunnel] %@", message)
        InspectSharedLog.append(scope: "InspectTunnel", message: message)
    }
}

private struct StartCompletionHandler: @unchecked Sendable {
    let callback: (Error?) -> Void
}

private enum InspectPacketTunnelRuntimeError: LocalizedError {
    case missingTunnelFileDescriptor
    case forwardingEngineExited(name: String, code: Int32)

    var errorDescription: String? {
        switch self {
        case .missingTunnelFileDescriptor:
            return "The packet tunnel did not expose a utun file descriptor."
        case let .forwardingEngineExited(name, code):
            return "The packet forwarding engine \(name) exited unexpectedly (code \(code))."
        }
    }
}
