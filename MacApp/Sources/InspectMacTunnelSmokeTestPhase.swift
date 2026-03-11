import SwiftUI

enum InspectMacTunnelSmokeTestPhase {
    case idle
    case running
    case succeeded
    case failed

    var title: String {
        switch self {
        case .idle:
            return "Ready"
        case .running:
            return "Running"
        case .succeeded:
            return "Succeeded"
        case .failed:
            return "Failed"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .running:
            return .orange
        case .succeeded:
            return .green
        case .failed:
            return .red
        }
    }
}
