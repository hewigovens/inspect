import Foundation
import OSLog
import Tun2SocksKit

final class Tun2SocksForwardingEngine: InspectTunnelForwardingEngine, @unchecked Sendable {
    let displayName = "Tun2Socks"
    let requiresLocalSocksRelay = true

    private let localSocksPort: UInt16
    private let logger: Logger
    private let stateQueue = DispatchQueue(label: "in.fourplex.Inspect.PacketTunnel.Tun2Socks")
    private var isRunning = false

    init(localSocksPort: UInt16, logger: Logger) {
        self.localSocksPort = localSocksPort
        self.logger = logger
    }

    func start(
        configuration _: InspectTunnelForwardingConfiguration,
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

        Socks5Tunnel.run(withConfig: .string(content: makeConfig())) { [weak self] code in
            self?.stateQueue.sync {
                self?.isRunning = false
            }
            exitHandler(code)
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

        Socks5Tunnel.quit()
    }

    func stats() -> InspectTunnelForwardingStats {
        let stats = Socks5Tunnel.stats
        return InspectTunnelForwardingStats(
            txPackets: stats.up.packets,
            txBytes: stats.up.bytes,
            rxPackets: stats.down.packets,
            rxBytes: stats.down.bytes
        )
    }

    private func makeConfig() -> String {
        """
        tunnel:
          mtu: 1500

        socks5:
          address: 127.0.0.1
          port: \(localSocksPort)
          udp: 'udp'

        mapdns:
          address: 198.18.0.2
          port: 53
          network: 240.0.0.0
          netmask: 240.0.0.0

        misc:
          task-stack-size: 24576
          tcp-buffer-size: 4096
          connect-timeout: 5000
          read-write-timeout: 60000
          log-file: stderr
          log-level: error
          limit-nofile: 4096
        """
    }
}
