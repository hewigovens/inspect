import Foundation

public actor TLSFlowObservationFeed {
    private let storage: TLSFlowObservationFeedStorage?
    private let key: String
    private var appendCount = 0
    private var drainCount = 0
    private let logger = InspectRuntimeLogger(category: "TLSFlowObservationFeed", scope: "InspectFeed")

    public init(
        appGroupIdentifier: String = InspectSharedContainer.appGroupIdentifier,
        key: String = "inspect.monitor.flow-observations.v1",
        maximumPendingItems: Int = 200
    ) {
        self.key = key
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "nil"

        if let containerURL = InspectSharedContainer.containerURL(appGroupIdentifier: appGroupIdentifier) {
            let fileURL = containerURL.appendingPathComponent(Self.fileName(for: key))
            self.storage = TLSFlowObservationFeedStorage(
                fileURL: fileURL,
                maximumPendingItems: maximumPendingItems
            )
            logger.verbose(
                "init appGroup=\(appGroupIdentifier) key=\(key) path=\(fileURL.path) bundle=\(bundleIdentifier)"
            )
        } else {
            self.storage = nil
            logger.critical(
                "init failed appGroup=\(appGroupIdentifier) key=\(key) because shared container URL is unavailable"
            )
        }
    }

    init(
        fileURL: URL,
        key: String = "inspect.monitor.flow-observations.v1",
        maximumPendingItems: Int = 200
    ) {
        self.key = key
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "nil"
        self.storage = TLSFlowObservationFeedStorage(
            fileURL: fileURL,
            maximumPendingItems: maximumPendingItems
        )
        logger.verbose("init key=\(key) path=\(fileURL.path) bundle=\(bundleIdentifier)")
    }

    public func append(_ observation: TLSFlowObservation) {
        guard let storage else {
            logger.critical("append skipped because shared observation storage is unavailable")
            return
        }

        do {
            let pendingCount = try storage.append(observation)
            let remoteHost = observation.remoteHost ?? "nil"
            let serverName = observation.serverName ?? "nil"
            let remotePort = observation.remotePort.map(String.init) ?? "nil"
            let certificateCount = observation.capturedCertificateChainDER.map { String($0.count) } ?? "nil"
            appendCount += 1
            if appendCount <= 10 || appendCount.isMultiple(of: 25) {
                logger.verbose(
                    "append count=\(appendCount) pending=\(pendingCount) host=\(remoteHost) sni=\(serverName) port=\(remotePort) certs=\(certificateCount)"
                )
            }
        } catch {
            logger.critical("append failed key=\(key): \(error.localizedDescription)")
        }
    }

    public func drain(maxCount: Int = 20) -> [TLSFlowObservation] {
        guard let storage else {
            logger.critical("drain skipped because shared observation storage is unavailable")
            return []
        }

        do {
            let result = try storage.drain(maxCount: maxCount)
            guard result.observations.isEmpty == false else {
                return []
            }

            drainCount += 1
            logger.verbose(
                "drain #\(drainCount) requested=\(maxCount) consumed=\(result.observations.count) remaining=\(result.remainingCount)"
            )
            return result.observations
        } catch {
            logger.critical("drain failed key=\(key): \(error.localizedDescription)")
            return []
        }
    }

    public func reset() {
        guard let storage else {
            logger.critical("reset skipped because shared observation storage is unavailable")
            return
        }

        do {
            try storage.reset()
            logger.verbose("reset key=\(key)")
        } catch {
            logger.critical("reset failed key=\(key): \(error.localizedDescription)")
        }
    }

    public func pendingCount() -> Int {
        guard let storage else {
            return 0
        }

        do {
            return try storage.pendingCount()
        } catch {
            logger.critical("pendingCount failed key=\(key): \(error.localizedDescription)")
            return 0
        }
    }

    private static func fileName(for key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let sanitized = String(
            key.unicodeScalars.map { scalar in
                allowed.contains(scalar) ? Character(scalar) : "_"
            }
        )
        return sanitized + ".json"
    }
}
