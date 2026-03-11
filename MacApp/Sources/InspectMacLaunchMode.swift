import Foundation

enum InspectMacLaunchMode {
    case standard
    case tunnelSmokeTest(InspectMacTunnelSmokeTestConfiguration)

    static var current: InspectMacLaunchMode {
        guard InspectMacTunnelSmokeTestConfiguration.isEnabled else {
            return .standard
        }

        return .tunnelSmokeTest(.fromEnvironment())
    }
}

struct InspectMacTunnelSmokeTestConfiguration {
    static let defaultProbeURL = URL(string: "https://example.com")!

    let probeURL: URL
    let autoQuit: Bool

    static var isEnabled: Bool {
        if CommandLine.arguments.contains("--smoke-test") {
            return true
        }

        let environment = ProcessInfo.processInfo.environment
        guard let value = environment["INSPECT_MAC_TUNNEL_SMOKETEST"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }

        return value == "1" || value == "true" || value == "yes"
    }

    static func fromEnvironment() -> InspectMacTunnelSmokeTestConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let probeURL = commandLineValue(for: "--smoke-test-url")
            .flatMap(URL.init(string:))
            ?? environment["INSPECT_MAC_TUNNEL_SMOKETEST_URL"].flatMap(URL.init(string:))
            ?? defaultProbeURL
        let autoQuitValue = commandLineValue(for: "--smoke-test-autoquit")?
            .lowercased()
            ?? environment["INSPECT_MAC_TUNNEL_SMOKETEST_AUTOQUIT"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        let autoQuit = autoQuitValue.map { value in
            value != "0" && value != "false" && value != "no"
        } ?? true

        return InspectMacTunnelSmokeTestConfiguration(
            probeURL: probeURL,
            autoQuit: autoQuit
        )
    }

    private static func commandLineValue(for flag: String) -> String? {
        guard let flagIndex = CommandLine.arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = CommandLine.arguments.index(after: flagIndex)
        guard valueIndex < CommandLine.arguments.endIndex else {
            return nil
        }

        return CommandLine.arguments[valueIndex]
    }
}
