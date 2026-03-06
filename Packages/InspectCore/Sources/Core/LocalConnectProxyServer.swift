import Foundation
import Network
import OSLog

final class LocalConnectProxyServer: @unchecked Sendable {
    typealias ObservationHandler = (_ host: String, _ port: UInt16) -> Void
    typealias OutboundConnectionFactory = (
        _ host: String,
        _ port: UInt16,
        _ stateHandler: @escaping @Sendable (ConnectProxyOutboundConnection.State, Error?) -> Void
    ) -> ConnectProxyOutboundConnection?

    private let listenPort: NWEndpoint.Port
    private let logger: Logger
    private let makeOutboundConnection: OutboundConnectionFactory
    private let observationHandler: ObservationHandler
    private let queue = DispatchQueue(label: "in.fourplex.Inspect.PacketTunnel.Proxy")

    private var listener: NWListener?
    private var sessions: [UUID: ConnectProxySession] = [:]

    init(
        listenPort: UInt16,
        logger: Logger,
        makeOutboundConnection: @escaping OutboundConnectionFactory,
        observationHandler: @escaping ObservationHandler
    ) throws {
        guard let port = NWEndpoint.Port(rawValue: listenPort) else {
            throw ProxyServerError.invalidListenPort
        }

        self.listenPort = port
        self.logger = logger
        self.makeOutboundConnection = makeOutboundConnection
        self.observationHandler = observationHandler
    }

    func start(timeout: TimeInterval = 5) throws {
        if listener != nil {
            return
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        log("Starting local CONNECT proxy on 127.0.0.1:\(listenPort.rawValue)")

        let startupState = ListenerStartupState()
        let startupSemaphore = DispatchSemaphore(value: 0)

        let listener = try NWListener(using: parameters, on: listenPort)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(
                state,
                startupState: startupState,
                startupSemaphore: startupSemaphore
            )
        }
        listener.start(queue: queue)
        self.listener = listener

        let waitResult = startupSemaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            stop()
            throw ProxyServerError.startupTimedOut
        }

        let result = startupState.result

        switch result {
        case .success:
            return
        case let .failure(error):
            stop()
            throw error
        case .none:
            stop()
            throw ProxyServerError.startupFailed
        }
    }

    func stop() {
        log("Stopping local CONNECT proxy")
        for session in sessions.values {
            session.stop()
        }
        sessions.removeAll()

        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
    }

    private func handleListenerState(
        _ state: NWListener.State,
        startupState: ListenerStartupState,
        startupSemaphore: DispatchSemaphore
    ) {
        switch state {
        case .ready:
            log("Local CONNECT proxy ready on port \(listenPort.rawValue)")
            let shouldSignal = startupState.setIfEmpty(.success(()))
            if shouldSignal {
                startupSemaphore.signal()
            }
        case let .failed(error):
            log("Local CONNECT proxy failed: \(error.localizedDescription)")
            let shouldSignal = startupState.setIfEmpty(.failure(error))
            if shouldSignal {
                startupSemaphore.signal()
            }
        case .cancelled:
            log("Local CONNECT proxy cancelled")
        default:
            break
        }
    }

    private func handle(_ inbound: NWConnection) {
        let sessionID = UUID()
        log("Accepted inbound proxy connection \(sessionID.uuidString)")
        let session = ConnectProxySession(
            sessionID: sessionID,
            inbound: inbound,
            logger: logger,
            queue: queue,
            makeOutboundConnection: makeOutboundConnection
        ) { [observationHandler] host, port in
            observationHandler(host, port)
        } onClose: { [weak self] in
            guard let self else {
                return
            }

            self.queue.async {
                self.sessions.removeValue(forKey: sessionID)
            }
        }

        sessions[sessionID] = session
        session.start()
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        NSLog("[InspectProxy] %@", message)
    }
}

public final class ConnectProxyOutboundConnection: @unchecked Sendable {
    public enum State: Sendable {
        case connecting
        case waiting
        case ready
        case closed
        case cancelled
        case failed
    }

    public typealias ReadHandler = (_ minimumLength: Int, _ maximumLength: Int, _ completion: @escaping (Data?, Error?) -> Void) -> Void
    public typealias WriteHandler = (_ data: Data, _ completion: @escaping (Error?) -> Void) -> Void

    private let readHandler: ReadHandler
    private let writeHandler: WriteHandler
    private let cancelHandler: () -> Void

    public init(
        readHandler: @escaping ReadHandler,
        writeHandler: @escaping WriteHandler,
        cancelHandler: @escaping () -> Void
    ) {
        self.readHandler = readHandler
        self.writeHandler = writeHandler
        self.cancelHandler = cancelHandler
    }

    func read(minimumLength: Int, maximumLength: Int, completion: @escaping (Data?, Error?) -> Void) {
        readHandler(minimumLength, maximumLength, completion)
    }

    func write(_ data: Data, completion: @escaping (Error?) -> Void) {
        writeHandler(data, completion)
    }

    func cancel() {
        cancelHandler()
    }
}

private final class ConnectProxySession: @unchecked Sendable {
    private let sessionID: UUID
    private let inbound: NWConnection
    private let logger: Logger
    private let queue: DispatchQueue
    private let makeOutboundConnection: LocalConnectProxyServer.OutboundConnectionFactory
    private let observationHandler: LocalConnectProxyServer.ObservationHandler
    private let onClose: () -> Void

    private var outbound: ConnectProxyOutboundConnection?
    private var headerBuffer = Data()
    private var didClose = false
    private var didSendConnectEstablished = false

    private let maxHeaderBytes = 16 * 1024
    private static let headerTerminator = Data("\r\n\r\n".utf8)

    init(
        sessionID: UUID,
        inbound: NWConnection,
        logger: Logger,
        queue: DispatchQueue,
        makeOutboundConnection: @escaping LocalConnectProxyServer.OutboundConnectionFactory,
        observationHandler: @escaping LocalConnectProxyServer.ObservationHandler,
        onClose: @escaping () -> Void
    ) {
        self.sessionID = sessionID
        self.inbound = inbound
        self.logger = logger
        self.queue = queue
        self.makeOutboundConnection = makeOutboundConnection
        self.observationHandler = observationHandler
        self.onClose = onClose
    }

    func start() {
        log("Starting proxy session")
        inbound.stateUpdateHandler = { [weak self] state in
            self?.handleInboundState(state)
        }
        inbound.start(queue: queue)
        readConnectRequestHeader()
    }

    func stop() {
        close()
    }

    private func handleInboundState(_ state: NWConnection.State) {
        switch state {
        case let .failed(error):
            log("Inbound connection failed: \(error.localizedDescription)")
            close()
        case .cancelled:
            log("Inbound connection cancelled")
            close()
        default:
            break
        }
    }

    private func readConnectRequestHeader() {
        inbound.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }
            guard self.didClose == false else {
                return
            }

            if let data, data.isEmpty == false {
                self.headerBuffer.append(data)
            }

            if isComplete || error != nil {
                if let error {
                    self.log("Inbound header read failed: \(error.localizedDescription)")
                } else {
                    self.log("Inbound header read completed before CONNECT request")
                }
                self.close()
                return
            }

            if self.headerBuffer.count > self.maxHeaderBytes {
                self.log("Inbound header exceeded \(self.maxHeaderBytes) bytes")
                self.replyAndClose("HTTP/1.1 431 Request Header Fields Too Large\r\n\r\n")
                return
            }

            if let range = self.headerBuffer.range(of: Self.headerTerminator) {
                let headerData = self.headerBuffer[..<range.lowerBound]
                self.handleRequestHeader(Data(headerData))
                return
            }

            self.readConnectRequestHeader()
        }
    }

    private func handleRequestHeader(_ headerData: Data) {
        guard let request = ConnectRequestParser.parse(headerData) else {
            log("Failed to parse proxy request header")
            replyAndClose("HTTP/1.1 400 Bad Request\r\n\r\n")
            return
        }

        guard request.method == "CONNECT" else {
            log("Rejected unsupported proxy method \(request.method)")
            replyAndClose("HTTP/1.1 501 Not Implemented\r\n\r\n")
            return
        }

        log("Parsed CONNECT \(request.host):\(request.port)")
        observationHandler(request.host, request.port)
        openOutboundTunnel(host: request.host, port: request.port)
    }

    private func openOutboundTunnel(host: String, port: UInt16) {
        log("Opening outbound tunnel to \(host):\(port)")
        guard let outbound = makeOutboundConnection(host, port, { [weak self] state, error in
            self?.handleOutboundState(state, error: error)
        }) else {
            log("Outbound connection factory returned nil for \(host):\(port)")
            replyAndClose("HTTP/1.1 502 Bad Gateway\r\n\r\n")
            return
        }

        self.outbound = outbound
    }

    private func handleOutboundState(_ state: ConnectProxyOutboundConnection.State, error: Error?) {
        guard didClose == false else {
            return
        }

        log("Outbound state \(String(describing: state))")
        switch state {
        case .ready:
            guard didSendConnectEstablished == false else {
                return
            }
            sendConnectEstablished()
        case .failed:
            if let error {
                log("CONNECT outbound failed: \(error.localizedDescription)")
            }
            if didSendConnectEstablished {
                close()
            } else {
                replyAndClose("HTTP/1.1 502 Bad Gateway\r\n\r\n")
            }
        case .closed, .cancelled:
            close()
        case .connecting, .waiting:
            break
        }
    }

    private func sendConnectEstablished() {
        didSendConnectEstablished = true
        log("Sending 200 Connection Established")
        inbound.send(content: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8), completion: .contentProcessed { [weak self] error in
            guard let self else {
                return
            }

            if error != nil {
                self.log("Failed to send 200 Connection Established")
                self.close()
                return
            }

            self.pipeInboundToOutbound()
            self.pipeOutboundToInbound()
        })
    }

    private func pipeInboundToOutbound() {
        guard let outbound else {
            close()
            return
        }

        inbound.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024) { [weak self, weak outbound] data, _, isComplete, error in
            guard let self,
                  let outbound,
                  self.didClose == false else {
                return
            }

            if let data, data.isEmpty == false {
                outbound.write(data) { [weak self] sendError in
                    guard let self else {
                        return
                    }

                    if sendError != nil {
                        self.log("Outbound write failed")
                        self.close()
                        return
                    }

                    self.pipeInboundToOutbound()
                }
                return
            }

            if isComplete || error != nil {
                if let error {
                    self.log("Inbound stream ended with error: \(error.localizedDescription)")
                } else {
                    self.log("Inbound stream completed")
                }
                self.close()
                return
            }

            self.pipeInboundToOutbound()
        }
    }

    private func pipeOutboundToInbound() {
        guard let outbound else {
            close()
            return
        }

        outbound.read(minimumLength: 1, maximumLength: 32 * 1024) { [weak self, weak outbound] data, error in
            guard let self,
                  outbound != nil,
                  self.didClose == false else {
                return
            }

            if let data, data.isEmpty == false {
                self.inbound.send(content: data, completion: .contentProcessed { [weak self] sendError in
                    guard let self else {
                        return
                    }

                    if sendError != nil {
                        self.log("Inbound write failed")
                        self.close()
                        return
                    }

                    self.pipeOutboundToInbound()
                })
                return
            }

            if error != nil || data == nil {
                if let error {
                    self.log("Outbound stream ended with error: \(error.localizedDescription)")
                } else {
                    self.log("Outbound stream completed")
                }
                self.close()
                return
            }

            self.pipeOutboundToInbound()
        }
    }

    private func replyAndClose(_ response: String) {
        let statusLine = response.split(separator: "\r\n").first.map(String.init) ?? response
        log("Replying to proxy client with \(statusLine)")
        inbound.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    private func close() {
        guard didClose == false else {
            return
        }
        didClose = true
        log("Closing proxy session")

        inbound.stateUpdateHandler = nil
        inbound.cancel()

        outbound?.cancel()
        outbound = nil

        onClose()
    }

    private func log(_ message: String) {
        logger.info("[\(self.sessionID.uuidString, privacy: .public)] \(message, privacy: .public)")
        NSLog("[InspectProxy][%@] %@", sessionID.uuidString, message)
    }
}

private final class ListenerStartupState: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var result: Result<Void, Error>?

    func setIfEmpty(_ newValue: Result<Void, Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard result == nil else {
            return false
        }

        result = newValue
        return true
    }
}

private struct ConnectRequest {
    let method: String
    let host: String
    let port: UInt16
}

private enum ConnectRequestParser {
    static func parse(_ data: Data) -> ConnectRequest? {
        guard let header = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = header.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, requestLine.isEmpty == false else {
            return nil
        }

        let pieces = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard pieces.count >= 2 else {
            return nil
        }

        let method = String(pieces[0]).uppercased()
        let target = String(pieces[1])
        guard let authority = parseAuthority(target) else {
            return nil
        }

        return ConnectRequest(method: method, host: authority.host, port: authority.port)
    }

    private static func parseAuthority(_ authority: String) -> (host: String, port: UInt16)? {
        if authority.hasPrefix("["),
           let closingBracket = authority.firstIndex(of: "]") {
            let host = String(authority[authority.index(after: authority.startIndex)..<closingBracket])
            let remainder = authority[authority.index(after: closingBracket)...]
            guard remainder.first == ":" else {
                return nil
            }
            let portString = remainder.dropFirst()
            guard let port = UInt16(portString), host.isEmpty == false else {
                return nil
            }
            return (host, port)
        }

        guard let separator = authority.lastIndex(of: ":") else {
            return nil
        }

        let host = String(authority[..<separator])
        let portString = String(authority[authority.index(after: separator)...])
        guard let port = UInt16(portString), host.isEmpty == false else {
            return nil
        }

        return (host, port)
    }
}

private enum ProxyServerError: Error {
    case invalidListenPort
    case startupFailed
    case startupTimedOut
}
