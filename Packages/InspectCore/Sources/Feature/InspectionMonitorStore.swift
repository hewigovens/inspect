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
    private var lastLeafFingerprintByHost: [String: String] = [:]
    private var feedPollingTask: Task<Void, Never>?
    private var defaultsObserver: NSObjectProtocol?

    private static let enabledKey = "inspect.monitor.enabled.v1"
    private static let historyLimit = 24

    init(
        monitorEngine: TLSMonitorProbeEngine = TLSMonitorProbeEngine(),
        flowObservationFeed: TLSFlowObservationFeed? = TLSFlowObservationFeed(),
        enableNetworkFeedPolling: Bool = true
    ) {
        self.monitorEngine = monitorEngine
        self.flowObservationFeed = flowObservationFeed
        self.enableNetworkFeedPolling = enableNetworkFeedPolling
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        let enabledKey = Self.enabledKey
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let latest = UserDefaults.standard.bool(forKey: enabledKey)
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
    }

    var monitoredHosts: [InspectionMonitoredHost] {
        var visitedHosts = Set<String>()
        var hosts: [InspectionMonitoredHost] = []

        for entry in entries {
            guard let host = host(for: entry.event)?.lowercased(),
                  visitedHosts.insert(host).inserted else {
                continue
            }

            hosts.append(InspectionMonitoredHost(
                host: host,
                lastEvent: entry.event,
                supportsActiveProbe: MonitorHostClassifier.isIPAddressLiteral(host) == false
            ))
        }

        return hosts
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
        entries = Array(entries.prefix(Self.historyLimit))
    }

    private func applyEnabledState(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
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

}
