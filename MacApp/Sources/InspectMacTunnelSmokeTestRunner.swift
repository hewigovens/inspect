import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class InspectMacTunnelSmokeTestRunner {
    var transcript = ""
    var phase: InspectMacTunnelSmokeTestPhase = .idle

    var phaseTitle: String {
        phase.title
    }

    var phaseColor: Color {
        phase.color
    }

    @ObservationIgnored
    let configuration: InspectMacTunnelSmokeTestConfiguration
    @ObservationIgnored
    let tunnelController = InspectMacTunnelSmokeTestController()
    @ObservationIgnored
    let transcriptStore = InspectMacTunnelSmokeTranscriptStore()
    @ObservationIgnored
    var task: Task<Void, Never>?

    init(configuration: InspectMacTunnelSmokeTestConfiguration) {
        self.configuration = configuration
    }

    func startIfNeeded() {
        guard task == nil else {
            return
        }

        task = Task { [weak self] in
            await self?.run()
        }
    }
}
