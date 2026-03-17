import Foundation

public enum LiveMonitorError: LocalizedError, Sendable {
    case capabilityMissing(platform: String)
    case configurationUnavailable

    public var errorDescription: String? {
        switch self {
        case .capabilityMissing(let platform):
            return "Packet Tunnel capability is unavailable for this \(platform). Enable Network Extensions (Packet Tunnel) for the app and extension IDs, then refresh signing."
        case .configurationUnavailable:
            return "Unable to create or load the Packet Tunnel configuration."
        }
    }
}

public enum LiveMonitorErrorNormalizer {
    public static func normalize(_ error: Error, platform: String) -> Error {
        let message = error.localizedDescription.lowercased()

        if message.contains("not entitled") || message.contains("permission denied") {
            return LiveMonitorError.capabilityMissing(platform: platform)
        }

        if message.contains("failed to load preferences")
            || message.contains("unable to load")
            || message.contains("unable to save") {
            return LiveMonitorError.configurationUnavailable
        }

        return error
    }
}
