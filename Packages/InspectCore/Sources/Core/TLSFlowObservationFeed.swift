import Foundation
import OSLog

public enum InspectSharedContainer {
    private static let infoDictionaryKey = "InspectAppGroupIdentifier"
    private static let defaultAppGroupIdentifier = "group.in.fourplex.inspect.monitor"
    private static let bootstrapLogger = Logger(
        subsystem: "in.fourplex.Inspect",
        category: "InspectSharedContainer"
    )

    public static let appGroupIdentifier: String = {
        if let value = ProcessInfo.processInfo.environment["INSPECT_APP_GROUP_IDENTIFIER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           value.isEmpty == false {
            bootstrapLogger.debug("Using app group from environment: \(value, privacy: .public)")
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                bootstrapLogger.debug(
                    "Using app group from Info.plist: \(trimmed, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "nil", privacy: .public)"
                )
                return trimmed
            }
        }

        bootstrapLogger.debug(
            "Falling back to default app group: \(defaultAppGroupIdentifier, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "nil", privacy: .public)"
        )
        return defaultAppGroupIdentifier
    }()
}

public actor TLSFlowObservationFeed {
    private let defaults: UserDefaults?
    private let key: String
    private let maximumPendingItems: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var appendCount = 0
    private var drainCount = 0
    private let logger = InspectRuntimeLogger(category: "TLSFlowObservationFeed", scope: "InspectFeed")

    public init(
        suiteName: String = InspectSharedContainer.appGroupIdentifier,
        key: String = "inspect.monitor.flow-observations.v1",
        maximumPendingItems: Int = 200
    ) {
        self.defaults = UserDefaults(suiteName: suiteName)
        self.key = key
        self.maximumPendingItems = maximumPendingItems
        let defaultsState = self.defaults == nil ? "nil" : "ok"
        logger.verbose(
            "init suite=\(suiteName) key=\(key) defaults=\(defaultsState) bundle=\(Bundle.main.bundleIdentifier ?? "nil")"
        )
    }

    public func append(_ observation: TLSFlowObservation) {
        guard let defaults,
              let encoded = encode(observation) else {
            logger.critical(
                "append skipped defaults=\(defaults == nil ? "nil" : "ok") encoded=\(encode(observation) == nil ? "nil" : "ok")"
            )
            return
        }

        var payloads = defaults.stringArray(forKey: key) ?? []
        payloads.append(encoded)

        if payloads.count > maximumPendingItems {
            payloads.removeFirst(payloads.count - maximumPendingItems)
        }

        defaults.set(payloads, forKey: key)
        appendCount += 1
        if appendCount <= 10 || appendCount.isMultiple(of: 25) {
            logger.verbose(
                "append count=\(appendCount) pending=\(payloads.count) host=\(observation.remoteHost ?? "nil") sni=\(observation.serverName ?? "nil") port=\(observation.remotePort.map(String.init) ?? "nil") certs=\(observation.capturedCertificateChainDER.map { String($0.count) } ?? "nil")"
            )
        }
    }

    public func drain(maxCount: Int = 20) -> [TLSFlowObservation] {
        guard let defaults else {
            logger.critical("drain skipped because defaults is nil")
            return []
        }

        var payloads = defaults.stringArray(forKey: key) ?? []
        guard payloads.isEmpty == false else {
            return []
        }

        let count = max(0, min(maxCount, payloads.count))
        let consumed = Array(payloads.prefix(count))
        payloads.removeFirst(count)
        defaults.set(payloads, forKey: key)
        drainCount += 1
        logger.verbose(
            "drain #\(drainCount) requested=\(maxCount) consumed=\(consumed.count) remaining=\(payloads.count)"
        )

        return consumed.compactMap(decode)
    }

    public func reset() {
        defaults?.removeObject(forKey: key)
        logger.verbose("reset key=\(key)")
    }

    public func pendingCount() -> Int {
        defaults?.stringArray(forKey: key)?.count ?? 0
    }

    private func encode(_ observation: TLSFlowObservation) -> String? {
        guard let data = try? encoder.encode(observation) else {
            return nil
        }

        return data.base64EncodedString()
    }

    private func decode(_ payload: String) -> TLSFlowObservation? {
        guard let data = Data(base64Encoded: payload) else {
            return nil
        }

        return try? decoder.decode(TLSFlowObservation.self, from: data)
    }
}
