import Observation
import SwiftUI

enum InspectMacSection: String, CaseIterable, Hashable, Identifiable {
    case inspect = "Inspect"
    case monitor = "Monitor"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .inspect:
            return "magnifyingglass.circle"
        case .monitor:
            return "wave.3.right.circle"
        case .settings:
            return "gearshape"
        }
    }
}

@MainActor
@Observable
final class InspectMacAppModel {
    var selectedSection: InspectMacSection? = .inspect
    var inspectSessionID = UUID()

    func startNewInspection() {
        selectedSection = .inspect
        inspectSessionID = UUID()
    }
}
