@testable import InspectCore
import Foundation
import Testing

@Test
func inspectLogConfigurationDefaultsToCriticalOnly() {
    let suiteName = makeSuiteName(testName: #function)
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    #expect(InspectLogConfiguration.current(suiteName: suiteName) == .criticalOnly)
}

@Test
func inspectLogConfigurationPersistsVerboseSetting() {
    let suiteName = makeSuiteName(testName: #function)
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }

    InspectLogConfiguration.set(.verbose, suiteName: suiteName)

    #expect(InspectLogConfiguration.current(suiteName: suiteName) == .verbose)
}

private func makeSuiteName(testName: String) -> String {
    "InspectLogConfigurationTests.\(testName.replacingOccurrences(of: " ", with: "-"))"
}
