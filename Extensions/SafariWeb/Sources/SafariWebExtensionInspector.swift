import Foundation
import InspectCore

final class SafariExtensionInspector {
    func inspect(
        input: String,
        completion: @escaping (Result<TLSInspectionReport, Error>) -> Void
    ) throws {
        let url = try URLInputNormalizer.normalize(input: input)
        inspectUsingSharedAsync(url: url, completionBox: SafariExtensionCompletionBox(completion))
    }

    private func inspectUsingSharedAsync(
        url: URL,
        completionBox: SafariExtensionCompletionBox
    ) {
        Task {
            do {
                let report = try await TLSInspector().inspect(url: url)
                DispatchQueue.main.async {
                    completionBox.completion(.success(report))
                }
            } catch {
                DispatchQueue.main.async {
                    completionBox.completion(.failure(error))
                }
            }
        }
    }
}

private final class SafariExtensionCompletionBox: @unchecked Sendable {
    let completion: (Result<TLSInspectionReport, Error>) -> Void

    init(_ completion: @escaping (Result<TLSInspectionReport, Error>) -> Void) {
        self.completion = completion
    }
}
