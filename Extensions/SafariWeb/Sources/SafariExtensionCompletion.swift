import Foundation
import InspectCore

final class SafariExtensionCompletion: @unchecked Sendable {
    let completion: (Result<TLSInspectionReport, Error>) -> Void

    init(_ completion: @escaping (Result<TLSInspectionReport, Error>) -> Void) {
        self.completion = completion
    }
}
