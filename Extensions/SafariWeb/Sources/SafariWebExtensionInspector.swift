import Foundation
import InspectCore

final class SafariExtensionInspector {
    func inspect(
        input: String,
        completion: @escaping (Result<TLSInspectionReport, Error>) -> Void
    ) throws {
        let url = try URLInputNormalizer.normalize(input: input)
        inspectAsync(url: url, completion: SafariExtensionCompletion(completion))
    }

    private func inspectAsync(
        url: URL,
        completion: SafariExtensionCompletion
    ) {
        Task {
            do {
                let inspection = try await TLSInspector().inspect(url: url)
                guard let report = inspection.primaryReport else {
                    throw InspectionError.missingServerTrust
                }
                DispatchQueue.main.async {
                    completion.completion(.success(report))
                }
            } catch {
                DispatchQueue.main.async {
                    completion.completion(.failure(error))
                }
            }
        }
    }
}
