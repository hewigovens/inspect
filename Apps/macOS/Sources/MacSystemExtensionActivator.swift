import Foundation
import SystemExtensions

final class MacSystemExtensionActivator: NSObject, OSSystemExtensionRequestDelegate, @unchecked Sendable {
    var onApprovalRequired: (() -> Void)?

    private var continuations: [ObjectIdentifier: CheckedContinuation<Void, Error>] = [:]

    func activate(identifier: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: identifier,
                queue: .main
            )
            request.delegate = self
            continuations[ObjectIdentifier(request)] = continuation
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }

    func requestNeedsUserApproval(_: OSSystemExtensionRequest) {
        onApprovalRequired?()
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult _: OSSystemExtensionRequest.Result
    ) {
        finish(request: request, result: .success(()))
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFailWithError error: Error
    ) {
        finish(request: request, result: .failure(error))
    }

    func request(
        _: OSSystemExtensionRequest,
        actionForReplacingExtension _: OSSystemExtensionProperties,
        withExtension _: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    private func finish(
        request: OSSystemExtensionRequest,
        result: Result<Void, Error>
    ) {
        let key = ObjectIdentifier(request)
        guard let continuation = continuations.removeValue(forKey: key) else {
            return
        }

        switch result {
        case .success:
            continuation.resume()
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}
