import Foundation
import InspectCore

final class TunnelForwardingEngine: InspectTunnelForwardingEngine, @unchecked Sendable {
    let displayName = "TunnelCore"

    private let logger: InspectRuntimeLogger
    private let core: TunnelCore
    private let stateQueue = DispatchQueue(label: "in.fourplex.Inspect.PacketTunnel.TunnelCore")
    private var isRunning = false
    private var exitMonitor: DispatchSourceTimer?

    init(
        logger: InspectRuntimeLogger,
        core: TunnelCore = TunnelCore()
    ) {
        self.logger = logger
        self.core = core
    }

    func start(
        configuration: InspectTunnelForwardingConfiguration,
        exitHandler: @escaping @Sendable (Int32) -> Void
    ) throws {
        let shouldStart = stateQueue.sync { () -> Bool in
            guard isRunning == false else {
                return false
            }

            isRunning = true
            return true
        }

        guard shouldStart else {
            return
        }

        do {
            try core.configureLogFile(path: InspectSharedLog.logFileURL()?.path)
            try core.setTunFileDescriptor(configuration.tunFileDescriptor)
            try core.start(
                configuration: TunnelCoreStartConfiguration(
                    ipv4Address: configuration.ipv4Address,
                    ipv6Address: configuration.ipv6Address,
                    dnsAddress: configuration.primaryDNSAddress,
                    fakeIpRange: configuration.fakeIPAddressRange,
                    mtu: configuration.mtu,
                    monitorEnabled: configuration.monitorEnabled,
                    verboseLoggingEnabled: configuration.logVerbosity.includesVerboseMessages
                )
            )
            try core.startLiveLoop()
            startExitMonitor(exitHandler: exitHandler)

            logger.verbose("Started tunnel core version=\(core.version)")
        } catch {
            stateQueue.sync {
                isRunning = false
            }
            stopExitMonitor()
            throw error
        }
    }

    func stop() {
        let shouldStop = stateQueue.sync { () -> Bool in
            guard isRunning else {
                return false
            }

            isRunning = false
            return true
        }

        guard shouldStop else {
            return
        }

        stopExitMonitor()
        core.stop()
        logger.verbose("Stopped tunnel core")
    }

    func stats() -> InspectTunnelForwardingStats {
        do {
            let stats = try core.stats()
            return InspectTunnelForwardingStats(
                txPackets: stats.txPackets,
                txBytes: stats.txBytes,
                rxPackets: stats.rxPackets,
                rxBytes: stats.rxBytes
            )
        } catch {
            logger.critical("Failed to read tunnel core stats: \(error.localizedDescription)")
            return InspectTunnelForwardingStats(txPackets: 0, txBytes: 0, rxPackets: 0, rxBytes: 0)
        }
    }

    func drainObservations() -> [TLSFlowObservation] {
        do {
            return try core.drainObservations().map(\.tlsFlowObservation)
        } catch {
            logger.critical("Failed to decode tunnel core observations: \(error.localizedDescription)")
            return []
        }
    }

    private func startExitMonitor(exitHandler: @escaping @Sendable (Int32) -> Void) {
        stopExitMonitor()

        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            guard self.isRunning else {
                return
            }

            do {
                guard let code = try self.core.takeExitCode() else {
                    return
                }

                self.isRunning = false
                self.stopExitMonitorLocked()
                exitHandler(code)
            } catch {
                self.logger.critical("Failed to poll tunnel core exit code: \(error.localizedDescription)")
            }
        }
        exitMonitor = timer
        timer.resume()
    }

    private func stopExitMonitor() {
        stateQueue.sync {
            stopExitMonitorLocked()
        }
    }

    private func stopExitMonitorLocked() {
        exitMonitor?.cancel()
        exitMonitor = nil
    }
}

private extension TunnelCoreObservation {
    var tlsFlowObservation: TLSFlowObservation {
        TLSFlowObservation(
            source: .networkExtension,
            transport: transportValue.inspectTransport,
            remoteHost: remoteHost,
            remotePort: remotePort,
            serverName: serverName,
            capturedCertificateChainDER: decodedCertificateChainDER()
        )
    }
}

private extension TunnelCoreTransport {
    var inspectTransport: TLSFlowTransport {
        switch self {
        case .tcp:
            return .tcp
        case .udp:
            return .udp
        case .unknown:
            return .unknown
        }
    }
}
