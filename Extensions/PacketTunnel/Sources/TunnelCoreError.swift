import Foundation

enum TunnelCoreError: LocalizedError {
    case operationFailed(operation: String, message: String)

    var errorDescription: String? {
        switch self {
        case let .operationFailed(operation, message):
            return "Tunnel core failed to \(operation): \(message)"
        }
    }
}
