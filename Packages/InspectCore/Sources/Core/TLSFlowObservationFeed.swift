import Foundation

public enum InspectSharedContainer {
    private static let infoDictionaryKey = "InspectAppGroupIdentifier"
    private static let defaultAppGroupIdentifier = "group.in.fourplex.inspect.monitor"

    public static let appGroupIdentifier: String = {
        if let value = ProcessInfo.processInfo.environment["INSPECT_APP_GROUP_IDENTIFIER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           value.isEmpty == false {
            NSLog("[InspectFeed] Using app group from environment: %@", value)
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                NSLog("[InspectFeed] Using app group from Info.plist: %@ bundle=%@", trimmed, Bundle.main.bundleIdentifier ?? "nil")
                return trimmed
            }
        }

        NSLog("[InspectFeed] Falling back to default app group: %@ bundle=%@", defaultAppGroupIdentifier, Bundle.main.bundleIdentifier ?? "nil")
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

    public init(
        suiteName: String = InspectSharedContainer.appGroupIdentifier,
        key: String = "inspect.monitor.flow-observations.v1",
        maximumPendingItems: Int = 200
    ) {
        self.defaults = UserDefaults(suiteName: suiteName)
        self.key = key
        self.maximumPendingItems = maximumPendingItems
        NSLog(
            "[InspectFeed] init suite=%@ key=%@ defaults=%@ bundle=%@",
            suiteName,
            key,
            self.defaults == nil ? "nil" : "ok",
            Bundle.main.bundleIdentifier ?? "nil"
        )
    }

    public func append(_ observation: TLSFlowObservation) {
        guard let defaults,
              let encoded = encode(observation) else {
            NSLog("[InspectFeed] append skipped defaults=%@ encoded=%@", defaults == nil ? "nil" : "ok", encode(observation) == nil ? "nil" : "ok")
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
            NSLog(
                "[InspectFeed] append count=%ld pending=%ld host=%@ sni=%@ port=%@ certs=%@",
                appendCount,
                payloads.count,
                observation.remoteHost ?? "nil",
                observation.serverName ?? "nil",
                observation.remotePort.map(String.init) ?? "nil",
                observation.capturedCertificateChainDER.map { String($0.count) } ?? "nil"
            )
        }
    }

    public func drain(maxCount: Int = 20) -> [TLSFlowObservation] {
        guard let defaults else {
            NSLog("[InspectFeed] drain skipped because defaults is nil")
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
        NSLog(
            "[InspectFeed] drain #%ld requested=%ld consumed=%ld remaining=%ld",
            drainCount,
            maxCount,
            consumed.count,
            payloads.count
        )

        return consumed.compactMap(decode)
    }

    public func reset() {
        defaults?.removeObject(forKey: key)
        NSLog("[InspectFeed] reset key=%@", key)
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
