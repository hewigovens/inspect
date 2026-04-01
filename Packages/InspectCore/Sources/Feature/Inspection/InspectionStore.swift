import Foundation
import InspectCore
import Observation

@MainActor
@Observable
public final class InspectionStore {
    public var input = ""
    public var inspection: TLSInspection?
    public var isLoading = false
    public var errorMessage: String?
    public private(set) var recentInputs: [String]
    private var hasConsumedInitialURL = false

    public init() {
        recentInputs = RecentInputStore.load()
    }

    public func bootstrap(initialURL: URL?) {
        guard hasConsumedInitialURL == false else {
            return
        }

        hasConsumedInitialURL = true

        guard let initialURL else {
            return
        }

        input = initialURL.absoluteString
        Task {
            await inspectCurrentInput()
        }
    }

    public func applyExternalRequest(_ request: InspectionExternalRequest) {
        errorMessage = nil

        switch request {
        case let .report(report, _):
            isLoading = false
            input = report.requestedURL.absoluteString
            inspection = TLSInspection(report: report)
            RecentInputStore.record(report.requestedURL.absoluteString)
            recentInputs = RecentInputStore.load()
        }
    }

    public func inspectCurrentInput() async {
        let candidate = input
        guard candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            errorMessage = "Enter a host name or HTTPS URL first."
            return
        }

        await inspect(candidate)
    }

    public func inspectRecent(_ recentInput: String) async {
        guard normalizedURL(from: recentInput) != inspection?.requestedURL else {
            return
        }

        input = recentInput
        await inspect(recentInput)
    }

    public func clearRecents() {
        RecentInputStore.clear()
        recentInputs = []
    }

    private func inspect(_ candidate: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let inspection = try await TLSInspector().inspect(input: candidate)
            self.inspection = inspection
            input = inspection.requestedURL.absoluteString
            RecentInputStore.record(inspection.requestedURL.absoluteString)
            recentInputs = RecentInputStore.load()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func normalizedURL(from candidate: String) -> URL? {
        try? URLInputNormalizer.normalize(input: candidate)
    }
}

private enum RecentInputStore {
    private static let key = "inspect.recent-inputs.v2"
    private static let limit = 8

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func record(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return
        }

        var values = load().filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        values.insert(trimmed, at: 0)
        UserDefaults.standard.set(Array(values.prefix(limit)), forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
