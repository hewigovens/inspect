import Foundation
import Network
import OSLog

final class LocalSocks5Server: @unchecked Sendable {
    typealias ObservationHandler = (_ observation: TLSFlowObservation) -> Void
    typealias OutboundConnectionFactory = (
        _ host: String,
        _ port: UInt16,
        _ stateHandler: @escaping @Sendable (ConnectProxyOutboundConnection.State, Error?) -> Void
    ) -> ConnectProxyOutboundConnection?

    private let listenPort: NWEndpoint.Port
    private let logger: Logger
    private let makeOutboundConnection: OutboundConnectionFactory
    private let observationHandler: ObservationHandler
    private let queue = DispatchQueue(label: "in.fourplex.Inspect.PacketTunnel.SOCKS")

    private var listener: NWListener?
    private var sessions: [UUID: Socks5Session] = [:]

    init(
        listenPort: UInt16,
        logger: Logger,
        makeOutboundConnection: @escaping OutboundConnectionFactory,
        observationHandler: @escaping ObservationHandler
    ) throws {
        guard let port = NWEndpoint.Port(rawValue: listenPort) else {
            throw LocalSocks5ServerError.invalidListenPort
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

        log("Starting local SOCKS5 relay on 127.0.0.1:\(listenPort.rawValue)")

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
            throw LocalSocks5ServerError.startupTimedOut
        }

        switch startupState.result {
        case .success:
            return
        case let .failure(error):
            stop()
            throw error
        case .none:
            stop()
            throw LocalSocks5ServerError.startupFailed
        }
    }

    func stop() {
        log("Stopping local SOCKS5 relay")
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
            log("Local SOCKS5 relay ready on port \(listenPort.rawValue)")
            if startupState.setIfEmpty(.success(())) {
                startupSemaphore.signal()
            }
        case let .failed(error):
            log("Local SOCKS5 relay failed: \(error.localizedDescription)")
            if startupState.setIfEmpty(.failure(error)) {
                startupSemaphore.signal()
            }
        case .cancelled:
            log("Local SOCKS5 relay cancelled")
        default:
            break
        }
    }

    private func handle(_ inbound: NWConnection) {
        let sessionID = UUID()
        log("Accepted inbound SOCKS5 connection \(sessionID.uuidString)")
        let session = Socks5Session(
            sessionID: sessionID,
            inbound: inbound,
            logger: logger,
            queue: queue,
            makeOutboundConnection: makeOutboundConnection,
            observationHandler: observationHandler
        ) { [weak self] in
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
        NSLog("[InspectSocks] %@", message)
        InspectSharedLog.append(scope: "InspectSocks", message: message)
    }
}

private final class Socks5Session: @unchecked Sendable {
    private let sessionID: UUID
    private let inbound: NWConnection
    private let logger: Logger
    private let queue: DispatchQueue
    private let makeOutboundConnection: LocalSocks5Server.OutboundConnectionFactory
    private let observationHandler: LocalSocks5Server.ObservationHandler
    private let onClose: () -> Void

    private var outbound: ConnectProxyOutboundConnection?
    private var controlBuffer = Data()
    private var requestedHost: String?
    private var requestedPort: UInt16?
    private var requestedServerName: String?
    private var observedServerName: String?
    private var clientHelloCapture = TLSClientHelloCapture()
    private var serverCertificateCapture = TLSServerCertificateCapture()
    private var didClose = false
    private var didSendSuccessReply = false
    private var didEmitInitialObservation = false
    private var didEmitCapturedCertificates = false

    init(
        sessionID: UUID,
        inbound: NWConnection,
        logger: Logger,
        queue: DispatchQueue,
        makeOutboundConnection: @escaping LocalSocks5Server.OutboundConnectionFactory,
        observationHandler: @escaping LocalSocks5Server.ObservationHandler,
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
        log("Starting SOCKS5 session")
        inbound.stateUpdateHandler = { [weak self] state in
            self?.handleInboundState(state)
        }
        inbound.start(queue: queue)
        readMethodSelection()
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

    private func readMethodSelection() {
        if let methodSelection = Socks5MethodSelectionParser.parse(controlBuffer) {
            controlBuffer.removeFirst(methodSelection.consumedBytes)

            guard methodSelection.version == 0x05 else {
                log("Unsupported SOCKS version \(methodSelection.version)")
                replyAndClose(Socks5Reply.methodSelection(0xFF))
                return
            }

            guard methodSelection.methods.contains(0x00) else {
                log("SOCKS5 client did not offer no-auth method")
                replyAndClose(Socks5Reply.methodSelection(0xFF))
                return
            }

            inbound.send(content: Socks5Reply.methodSelection(0x00), completion: .contentProcessed { [weak self] error in
                guard let self else {
                    return
                }

                if error != nil {
                    self.log("Failed to send SOCKS5 method selection reply")
                    self.close()
                    return
                }

                self.readConnectRequest()
            })
            return
        }

        receiveControlData { [weak self] in
            self?.readMethodSelection()
        }
    }

    private func readConnectRequest() {
        if let request = Socks5ConnectRequestParser.parse(controlBuffer) {
            controlBuffer.removeFirst(request.consumedBytes)

            requestedHost = request.host
            requestedPort = request.port
            requestedServerName = request.requestedServerName
            log("Parsed SOCKS5 command=\(request.command) target=\(request.host):\(request.port)")

            switch request.command {
            case 0x01:
                emitInitialObservationIfNeeded()
                openOutboundTunnel(host: request.host, port: request.port)
            case 0x03:
                log("Rejecting UDP ASSOCIATE for \(request.host):\(request.port)")
                replyAndClose(Socks5Reply.failure(0x07))
            default:
                log("Rejecting unsupported SOCKS5 command \(request.command)")
                replyAndClose(Socks5Reply.failure(0x07))
            }
            return
        }

        receiveControlData { [weak self] in
            self?.readConnectRequest()
        }
    }

    private func receiveControlData(completion: @escaping @Sendable () -> Void) {
        inbound.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else {
                return
            }
            guard self.didClose == false else {
                return
            }

            if let data, data.isEmpty == false {
                self.controlBuffer.append(data)
            }

            if isComplete || error != nil {
                if let error {
                    self.log("Inbound control read failed: \(error.localizedDescription)")
                } else {
                    self.log("Inbound control stream ended before relay setup")
                }
                self.close()
                return
            }

            completion()
        }
    }

    private func openOutboundTunnel(host: String, port: UInt16) {
        guard let outbound = makeOutboundConnection(host, port, { [weak self] state, error in
            self?.handleOutboundState(state, error: error)
        }) else {
            log("Outbound connection factory returned nil for \(host):\(port)")
            replyAndClose(Socks5Reply.failure(0x01))
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
            guard didSendSuccessReply == false else {
                return
            }
            sendSuccessReply()
        case .failed:
            if let error {
                log("SOCKS5 outbound failed: \(error.localizedDescription)")
            }
            if didSendSuccessReply {
                close()
            } else {
                replyAndClose(Socks5Reply.failure(0x05))
            }
        case .closed, .cancelled:
            close()
        case .connecting, .waiting:
            break
        }
    }

    private func sendSuccessReply() {
        didSendSuccessReply = true
        inbound.send(content: Socks5Reply.success(), completion: .contentProcessed { [weak self] error in
            guard let self else {
                return
            }

            if error != nil {
                self.log("Failed to send SOCKS5 success reply")
                self.close()
                return
            }

            let initialPayload = self.controlBuffer
            self.controlBuffer.removeAll()

            if initialPayload.isEmpty == false {
                self.forwardInitialInboundPayload(initialPayload)
                return
            }

            self.pipeInboundToOutbound()
            self.pipeOutboundToInbound()
        })
    }

    private func forwardInitialInboundPayload(_ data: Data) {
        guard let outbound else {
            close()
            return
        }

        observeClientHandshake(data)
        outbound.write(data) { [weak self] error in
            guard let self else {
                return
            }

            if error != nil {
                self.log("Failed to forward initial client payload")
                self.close()
                return
            }

            self.pipeInboundToOutbound()
            self.pipeOutboundToInbound()
        }
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
                self.observeClientHandshake(data)
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
                self.observeServerHandshake(data)
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

    private func emitInitialObservationIfNeeded() {
        guard didEmitInitialObservation == false else {
            return
        }

        didEmitInitialObservation = true
        emitObservation(capturedCertificateChainDER: nil)
    }

    private func observeClientHandshake(_ data: Data) {
        guard let serverName = clientHelloCapture.ingest(data),
              serverName != observedServerName else {
            return
        }

        observedServerName = serverName
        log("Observed client hello SNI \(serverName)")
        emitObservation(capturedCertificateChainDER: nil)
    }

    private func observeServerHandshake(_ data: Data) {
        guard didEmitCapturedCertificates == false,
              let certificates = serverCertificateCapture.ingest(data) else {
            return
        }

        didEmitCapturedCertificates = true
        log("Captured TLS certificate chain count=\(certificates.count)")
        emitObservation(capturedCertificateChainDER: certificates)
    }

    private func emitObservation(capturedCertificateChainDER: [Data]?) {
        guard let requestedHost,
              let requestedPort else {
            return
        }

        let observation = TLSFlowObservation(
            source: .networkExtension,
            transport: .tcp,
            remoteHost: requestedHost,
            remotePort: Int(requestedPort),
            serverName: observedServerName ?? requestedServerName,
            sourceAppIdentifier: nil,
            capturedCertificateChainDER: capturedCertificateChainDER
        )
        observationHandler(observation)
    }

    private func replyAndClose(_ response: Data) {
        inbound.send(content: response, completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    private func close() {
        guard didClose == false else {
            return
        }
        didClose = true
        log("Closing SOCKS5 session")

        inbound.stateUpdateHandler = nil
        inbound.cancel()

        outbound?.cancel()
        outbound = nil

        onClose()
    }

    private func log(_ message: String) {
        logger.info("[\(self.sessionID.uuidString, privacy: .public)] \(message, privacy: .public)")
        NSLog("[InspectSocks][%@] %@", sessionID.uuidString, message)
        InspectSharedLog.append(scope: "InspectSocks", message: "[\(sessionID.uuidString)] \(message)")
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

private struct Socks5MethodSelection {
    let version: UInt8
    let methods: [UInt8]
    let consumedBytes: Int
}

private enum Socks5MethodSelectionParser {
    static func parse(_ data: Data) -> Socks5MethodSelection? {
        guard data.count >= 2 else {
            return nil
        }

        let version = data[0]
        let methodCount = Int(data[1])
        let totalLength = 2 + methodCount
        guard data.count >= totalLength else {
            return nil
        }

        return Socks5MethodSelection(
            version: version,
            methods: Array(data[2..<totalLength]),
            consumedBytes: totalLength
        )
    }
}

private struct Socks5ConnectRequest {
    let command: UInt8
    let host: String
    let port: UInt16
    let requestedServerName: String?
    let consumedBytes: Int
}

private enum Socks5ConnectRequestParser {
    static func parse(_ data: Data) -> Socks5ConnectRequest? {
        guard data.count >= 4, data[0] == 0x05 else {
            return nil
        }

        let command = data[1]
        let addressType = data[3]
        var cursor = 4
        let host: String

        switch addressType {
        case 0x01:
            guard data.count >= cursor + 4 else {
                return nil
            }
            host = [
                String(data[cursor]),
                String(data[cursor + 1]),
                String(data[cursor + 2]),
                String(data[cursor + 3])
            ].joined(separator: ".")
            cursor += 4
        case 0x03:
            guard data.count >= cursor + 1 else {
                return nil
            }

            let length = Int(data[cursor])
            cursor += 1
            guard data.count >= cursor + length else {
                return nil
            }

            let hostData = data[cursor..<(cursor + length)]
            guard let decodedHost = String(data: hostData, encoding: .utf8),
                  decodedHost.isEmpty == false else {
                return nil
            }
            host = decodedHost
            cursor += length
        case 0x04:
            guard data.count >= cursor + 16 else {
                return nil
            }

            host = parseIPv6(data[cursor..<(cursor + 16)])
            cursor += 16
        default:
            return nil
        }

        guard data.count >= cursor + 2 else {
            return nil
        }

        let port = (UInt16(data[cursor]) << 8) | UInt16(data[cursor + 1])
        cursor += 2

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedHost.isEmpty == false else {
            return nil
        }

        let requestedServerName = HostLiteralClassifier.isIPAddressLiteral(trimmedHost)
            ? nil
            : trimmedHost.lowercased()

        return Socks5ConnectRequest(
            command: command,
            host: trimmedHost,
            port: port,
            requestedServerName: requestedServerName,
            consumedBytes: cursor
        )
    }

    private static func parseIPv6(_ data: Data.SubSequence) -> String {
        var segments: [String] = []
        var cursor = data.startIndex

        while cursor < data.endIndex {
            let next = data.index(cursor, offsetBy: 1)
            let segment = (UInt16(data[cursor]) << 8) | UInt16(data[next])
            segments.append(String(segment, radix: 16))
            cursor = data.index(cursor, offsetBy: 2)
        }

        return segments.joined(separator: ":")
    }
}

private enum Socks5Reply {
    static func methodSelection(_ method: UInt8) -> Data {
        Data([0x05, method])
    }

    static func success() -> Data {
        Data([0x05, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    static func failure(_ code: UInt8) -> Data {
        Data([0x05, code, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }
}

private enum HostLiteralClassifier {
    static func isIPAddressLiteral(_ value: String) -> Bool {
        if isIPv4Address(value) {
            return true
        }

        if value.contains(":") {
            let unwrapped = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            return unwrapped.isEmpty == false
                && unwrapped.allSatisfy { $0.isHexDigit || $0 == ":" || $0 == "." }
        }

        return false
    }

    private static func isIPv4Address(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 4 else {
            return false
        }

        for component in components {
            guard component.isEmpty == false,
                  component.count <= 3,
                  let number = Int(component),
                  (0...255).contains(number) else {
                return false
            }
        }

        return true
    }
}

private enum LocalSocks5ServerError: Error {
    case invalidListenPort
    case startupFailed
    case startupTimedOut
}
