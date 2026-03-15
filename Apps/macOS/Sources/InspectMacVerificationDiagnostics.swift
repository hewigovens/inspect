import Foundation
import InspectCore

@MainActor
final class InspectMacVerificationDiagnostics {
    private let logger = InspectRuntimeLogger(
        category: "MacVerification",
        scope: "InspectMac"
    )

    func ensureVerboseLoggingEnabled() {
        guard InspectLogConfiguration.current() != .verbose else {
            return
        }

        InspectLogConfiguration.set(.verbose)
        info("Enabled verbose shared logging for verification")
    }

    func info(_ message: String) {
        logger.verbose(message)
    }

    func error(prefix: String, error: Error) {
        let nsError = error as NSError
        let details = "\(prefix): \(nsError.localizedDescription) domain=\(nsError.domain) code=\(nsError.code)"
        logger.critical(details)
    }
}
