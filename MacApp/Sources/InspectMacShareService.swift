import AppKit
import InspectCore
import InspectFeature

@MainActor
final class InspectMacShareService: NSObject {
    @objc(inspectSelection:userData:error:)
    func inspectSelection(
        _ pasteboard: NSPasteboard,
        userData: String?,
        serviceError: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        guard let candidate = candidate(from: pasteboard) else {
            serviceError?.pointee = "Inspect could not read a host name or HTTPS URL from the current selection."
            return
        }

        do {
            let normalized = try URLInputNormalizer.normalize(input: candidate)
            NSApplication.shared.activate(ignoringOtherApps: true)
            InspectionExternalInputCenter.submitInput(normalized.absoluteString)
        } catch let submissionError {
            serviceError?.pointee = errorMessage(for: submissionError)
        }
    }

    private func candidate(from pasteboard: NSPasteboard) -> String? {
        if let string = pasteboard.string(forType: .URL), string.isEmpty == false {
            return string
        }

        if let string = pasteboard.string(forType: .string), string.isEmpty == false {
            return string
        }

        return nil
    }

    private func errorMessage(for error: any Error) -> NSString {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description as NSString
        }

        return error.localizedDescription as NSString
    }
}
