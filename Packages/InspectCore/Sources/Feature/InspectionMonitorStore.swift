import Foundation
import InspectCore
import Observation

@MainActor
@Observable
final class InspectionMonitorStore {
    var isEnabled: Bool
    var isApplyingLiveMonitorToggle = false
    var liveMonitorMessage: String?
    private(set) var entries: [InspectionMonitorEntry] = []

    private let monitorEngine: TLSMonitorProbeEngine
    private let flowObservationFeed: TLSFlowObservationFeed?
    private let enableNetworkFeedPolling: Bool
    private let userDefaults: UserDefaults
    private var lastLeafFingerprintByHost: [String: String] = [:]
    private var feedPollingTask: Task<Void, Never>?
    private var defaultsObserver: NSObjectProtocol?

    private static let enabledKey = "inspect.monitor.enabled.v1"
    private static let entriesKey = "inspect.monitor.entries.v1"
    private static let eventHistoryLimit = 128
    private static let hostHistoryLimit = 36

    init(
        monitorEngine: TLSMonitorProbeEngine = TLSMonitorProbeEngine(),
        flowObservationFeed: TLSFlowObservationFeed? = TLSFlowObservationFeed(),
        enableNetworkFeedPolling: Bool = true,
        userDefaults: UserDefaults = .standard
    ) {
        self.monitorEngine = monitorEngine
        self.flowObservationFeed = flowObservationFeed
        self.enableNetworkFeedPolling = enableNetworkFeedPolling
        self.userDefaults = userDefaults
        self.isEnabled = userDefaults.bool(forKey: Self.enabledKey)
        self.entries = Self.loadPersistedEntries(from: userDefaults)
        self.lastLeafFingerprintByHost = Self.makeFingerprintIndex(from: entries)
        let enabledKey = Self.enabledKey
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let latest = self.userDefaults.bool(forKey: enabledKey)
                if self.isEnabled != latest, self.isApplyingLiveMonitorToggle == false {
                    self.isEnabled = latest
                }
            }
        }
        startFeedPolling()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled || isApplyingLiveMonitorToggle else {
            return
        }

        guard let toggleHandler = InspectionLiveMonitorCoordinator.currentToggleHandler() else {
            applyEnabledState(enabled)
            return
        }

        let previousValue = isEnabled
        isApplyingLiveMonitorToggle = true
        liveMonitorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await toggleHandler(enabled)
                self.applyEnabledState(enabled)
                self.liveMonitorMessage = nil
            } catch {
                self.isEnabled = previousValue
                self.liveMonitorMessage = error.localizedDescription
            }

            self.isApplyingLiveMonitorToggle = false
        }
    }

    func ingest(_ observation: TLSFlowObservation) {
        guard isEnabled else {
            return
        }

        Task {
            let event = await monitorEngine.handle(observation)
            await MainActor.run {
                append(event)
            }
        }
    }

    func recordInspection(_ report: TLSInspectionReport) {
        guard isEnabled else {
            return
        }

        let observation = TLSFlowObservation(
            source: .manualInspection,
            transport: .tcp,
            remoteHost: report.host,
            remotePort: report.requestedURL.port,
            serverName: report.host,
            negotiatedProtocol: report.networkProtocolName
        )

        append(TLSProbeEvent(
            observation: observation,
            result: .captured(report)
        ))
    }

    func clear() {
        entries = []
        lastLeafFingerprintByHost = [:]
        persistEntries()
    }

    var hostCount: Int {
        monitoredHosts.count
    }

    var lastActivityAt: Date? {
        entries.first?.event.occurredAt
    }

    var lastActivityTitle: String {
        guard let lastActivityAt else {
            return "Idle"
        }

        return lastActivityAt.formatted(date: .omitted, time: .shortened)
    }

    var monitoredHosts: [InspectionMonitoredHost] {
        var hostOrder: [String] = []
        var visitedHosts = Set<String>()
        var entriesByHost: [String: [InspectionMonitorEntry]] = [:]
        var latestCapturedReportByHost: [String: TLSInspectionReport] = [:]

        for entry in entries {
            guard let host = host(for: entry.event)?.lowercased() else {
                continue
            }

            entriesByHost[host, default: []].append(entry)
            if visitedHosts.insert(host).inserted {
                hostOrder.append(host)
            }

            guard case let .captured(report) = entry.event.result,
                  latestCapturedReportByHost[host] == nil else {
                continue
            }

            latestCapturedReportByHost[host] = report
        }

        return hostOrder.prefix(Self.hostHistoryLimit).compactMap { host in
            makeMonitoredHost(
                host: host,
                entries: entriesByHost[host] ?? [],
                latestReport: latestCapturedReportByHost[host]
            )
        }
    }

    func latestCapturedReport(forHost hostName: String) -> TLSInspectionReport? {
        let normalizedHost = hostName.lowercased()

        for entry in entries {
            guard case let .captured(report) = entry.event.result,
                  report.host.lowercased() == normalizedHost else {
                continue
            }

            return report
        }

        return nil
    }

    func entries(forHost hostName: String) -> [InspectionMonitorEntry] {
        let normalizedHost = hostName.lowercased()
        return entries.filter { entry in
            host(for: entry.event)?.lowercased() == normalizedHost
        }
    }

    func probeHost(_ host: String) async {
        guard isEnabled else {
            return
        }

        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return
        }
        guard MonitorHostClassifier.isIPAddressLiteral(trimmed.lowercased()) == false else {
            return
        }

        let observation = TLSFlowObservation(
            source: .manualInspection,
            transport: .tcp,
            remoteHost: trimmed,
            remotePort: 443,
            serverName: trimmed
        )
        let event = await monitorEngine.handle(observation)
        append(event)
    }

    private func startFeedPolling() {
        guard enableNetworkFeedPolling else {
            return
        }

        feedPollingTask?.cancel()
        feedPollingTask = Task { [weak self] in
            while Task.isCancelled == false {
                guard let self else {
                    return
                }

                await self.pollFeedIfNeeded()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func pollFeedIfNeeded() async {
        guard isEnabled,
              let flowObservationFeed else {
            return
        }

        let observations = await flowObservationFeed.drain(maxCount: 16)
        guard observations.isEmpty == false else {
            return
        }

        for observation in observations {
            ingest(observation)
        }
    }

    private func append(_ event: TLSProbeEvent) {
        let note = makeNoteIfNeeded(for: event)
        entries.insert(InspectionMonitorEntry(event: event, note: note), at: 0)
        entries = Array(entries.prefix(Self.eventHistoryLimit))
        persistEntries()
    }

    private func applyEnabledState(_ enabled: Bool) {
        isEnabled = enabled
        userDefaults.set(enabled, forKey: Self.enabledKey)
    }

    private func host(for event: TLSProbeEvent) -> String? {
        switch event.result {
        case let .captured(report):
            return MonitorHostClassifier.normalizedDisplayHost(report.host)
        case .failed, .skippedMissingHost, .skippedThrottled:
            return MonitorHostClassifier.normalizedDisplayHost(event.observation.probeHost)
                ?? MonitorHostClassifier.normalizedDisplayHost(event.observation.remoteHost)
        }
    }

    private func makeMonitoredHost(
        host: String,
        entries: [InspectionMonitorEntry],
        latestReport: TLSInspectionReport?
    ) -> InspectionMonitoredHost? {
        guard let lastEntry = entries.first else {
            return nil
        }

        let supportsActiveProbe = MonitorHostClassifier.isIPAddressLiteral(host) == false
        let firstSeenAt = entries.last?.event.occurredAt ?? lastEntry.event.occurredAt
        let state: InspectionMonitoredHostState
        let certificateAvailability: InspectionMonitoredHostCertificateAvailability

        if let latestReport {
            certificateAvailability = .captured
            state = latestReport.trust.isTrusted ? .trusted : .needsReview
        } else {
            certificateAvailability = .pending
            state = supportsActiveProbe ? .awaitingCertificate : .hostnameUnavailable
        }

        return InspectionMonitoredHost(
            host: host,
            lastEvent: lastEntry.event,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastEntry.event.occurredAt,
            latestReport: latestReport,
            state: state,
            certificateAvailability: certificateAvailability
        )
    }

    private func makeNoteIfNeeded(for event: TLSProbeEvent) -> String? {
        guard case let .captured(report) = event.result else {
            return nil
        }

        let host = report.host.lowercased()
        guard let leafFingerprint = report.leafCertificate?.fingerprints.first(where: {
            $0.label.caseInsensitiveCompare("SHA-256") == .orderedSame
        })?.value else {
            return nil
        }

        defer {
            lastLeafFingerprintByHost[host] = leafFingerprint
        }

        guard let previous = lastLeafFingerprintByHost[host], previous != leafFingerprint else {
            return nil
        }

        return "Leaf certificate fingerprint changed since the previous probe."
    }

    private func persistEntries() {
        let snapshots = entries.map(InspectionMonitorEntrySnapshot.init)
        guard let data = try? JSONEncoder().encode(snapshots) else {
            return
        }

        userDefaults.set(data, forKey: Self.entriesKey)
    }

    private static func loadPersistedEntries(from userDefaults: UserDefaults) -> [InspectionMonitorEntry] {
        guard let data = userDefaults.data(forKey: entriesKey),
              let snapshots = try? JSONDecoder().decode([InspectionMonitorEntrySnapshot].self, from: data) else {
            return []
        }

        return snapshots.map(\.entry)
    }

    private static func makeFingerprintIndex(from entries: [InspectionMonitorEntry]) -> [String: String] {
        var index: [String: String] = [:]

        for entry in entries.reversed() {
            guard case let .captured(report) = entry.event.result,
                  let leafFingerprint = report.leafCertificate?.fingerprints.first(where: {
                      $0.label.caseInsensitiveCompare("SHA-256") == .orderedSame
                  })?.value else {
                continue
            }

            index[report.host.lowercased()] = leafFingerprint
        }

        return index
    }
}

private struct InspectionMonitorEntrySnapshot: Codable {
    let event: TLSProbeEvent
    let note: String?

    init(entry: InspectionMonitorEntry) {
        self.event = entry.event
        self.note = entry.note
    }

    var entry: InspectionMonitorEntry {
        InspectionMonitorEntry(event: event, note: note)
    }
}
