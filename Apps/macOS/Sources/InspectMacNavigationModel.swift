import Foundation
import InspectFeature
import Observation

@MainActor
@Observable
final class InspectMacAppModel {
    var selectedSection: InspectSection? = .inspect
    var inspectSessionID = UUID()

    func startNewInspection() {
        selectedSection = .inspect
        inspectSessionID = UUID()
    }
}
