import Foundation
import InspectCore
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let inspector = SafariExtensionInspector()

    func beginRequest(with context: NSExtensionContext) {
        guard let request = SafariWebExtensionRequest(item: context.inputItems.first as? NSExtensionItem) else {
            SafariWebExtensionResponse.complete(
                context: context,
                payload: SafariWebExtensionPayload.error("Safari sent an invalid Inspect extension request.")
            )
            return
        }

        switch request.type {
        case "inspect-tab":
            guard let urlString = request.urlString else {
                SafariWebExtensionResponse.complete(
                    context: context,
                    payload: SafariWebExtensionPayload.error("The current page URL was unavailable.")
                )
                return
            }

            let box = ExtensionContextBox(context)
            do {
                try inspector.inspect(input: urlString) { result in
                    let payload: [String: Any]
                    switch result {
                    case let .success(report):
                        payload = SafariWebExtensionPayload.success(for: report)
                    case let .failure(error):
                        payload = SafariWebExtensionPayload.error(error.localizedDescription)
                    }

                    SafariWebExtensionResponse.complete(context: box.context, payload: payload)
                }
            } catch {
                SafariWebExtensionResponse.complete(
                    context: context,
                    payload: SafariWebExtensionPayload.error(error.localizedDescription)
                )
            }
        case "open-full-details":
            guard let token = request.reportToken else {
                SafariWebExtensionResponse.complete(
                    context: context,
                    payload: SafariWebExtensionPayload.error("No stored inspection was available to open.")
                )
                return
            }

            let box = ExtensionContextBox(context)
            box.context.open(InspectDeepLink.certificateDetail(token: token).url) { success in
                SafariWebExtensionResponse.complete(
                    context: box.context,
                    payload: success
                        ? ["status": "opened"]
                        : SafariWebExtensionPayload.error("Inspect could not be opened from the Safari extension.")
                )
            }
        default:
            SafariWebExtensionResponse.complete(
                context: context,
                payload: SafariWebExtensionPayload.error("Unsupported Safari extension request: \(request.type)")
            )
        }
    }
}

private final class ExtensionContextBox: @unchecked Sendable {
    let context: NSExtensionContext

    init(_ context: NSExtensionContext) {
        self.context = context
    }
}
