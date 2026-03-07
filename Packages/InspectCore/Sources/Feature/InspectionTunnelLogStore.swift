import Foundation
import InspectCore
import Observation

@MainActor
@Observable
final class InspectionTunnelLogStore {
    static let emptyStateText = "No tunnel log yet. Start Live Monitor to generate logs."
    static let clearedStateText = "Tunnel log cleared."

    var text = emptyStateText
    var autoRefresh = true

    var canShare: Bool {
        [Self.emptyStateText, Self.clearedStateText].contains(text) == false
    }

    func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let text = InspectSharedLog.readTail()
            Task { @MainActor in
                self.text = text ?? Self.emptyStateText
            }
        }
    }

    func clear() {
        DispatchQueue.global(qos: .utility).async {
            InspectSharedLog.reset()
            Task { @MainActor in
                self.text = Self.clearedStateText
            }
        }
    }

    func copyToClipboard() {
        InspectClipboard.copy(text)
    }
}
