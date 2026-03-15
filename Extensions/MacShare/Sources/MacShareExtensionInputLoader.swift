import AppKit
import InspectCore
import UniformTypeIdentifiers

@MainActor
enum MacShareExtensionInputLoader {
    static func loadInput(from context: NSExtensionContext, logger: InspectRuntimeLogger) async -> String? {
        guard let items = context.inputItems as? [NSExtensionItem] else {
            logger.critical("share request inputItems were not NSExtensionItem values")
            return nil
        }

        logger.critical("share request received \(items.count) extension item(s)")

        for (itemIndex, item) in items.enumerated() {
            let providers = item.attachments ?? []
            let title = item.attributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let body = item.attributedContentText?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            logger.critical(
                "share item \(itemIndex) has \(providers.count) attachment(s), title='\(title)', body='\(body)'"
            )

            for (providerIndex, provider) in providers.enumerated() {
                logger.critical(
                    "share item \(itemIndex) provider \(providerIndex) types: \(provider.registeredTypeIdentifiers.joined(separator: ", "))"
                )
            }
        }

        for item in items {
            for provider in item.attachments ?? [] {
                if let value = await loadURLString(from: provider) {
                    return value
                }
            }
        }

        for item in items {
            for provider in item.attachments ?? [] {
                if let value = await loadTextString(from: provider) {
                    return value
                }
            }
        }

        for item in items {
            if let body = item.attributedContentText?.string,
               body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return body
            }

            if let title = item.attributedTitle?.string,
               title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return title
            }
        }

        return nil
    }

    private static func loadURLString(from provider: NSItemProvider) async -> String? {
        if let url = try? await loadURLObject(from: provider) {
            return url.absoluteString
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let value = await loadItemString(from: provider, typeIdentifier: UTType.url.identifier) {
            return value
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let value = await loadItemString(from: provider, typeIdentifier: UTType.fileURL.identifier) {
            return value
        }

        return nil
    }

    private static func loadTextString(from provider: NSItemProvider) async -> String? {
        if let text = try? await loadTextObject(from: provider) {
            return trimmed(text)
        }

        for typeIdentifier in [UTType.plainText.identifier, UTType.text.identifier]
        where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            if let value = await loadItemString(from: provider, typeIdentifier: typeIdentifier) {
                return trimmed(value)
            }
        }

        return nil
    }

    private static func loadItemString(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: stringValue(from: item))
            }
        }
    }

    private static func loadURLObject(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: NSURL.self) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let item = item as? NSURL {
                    continuation.resume(returning: item as URL)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: NSCocoaErrorDomain,
                            code: NSFeatureUnsupportedError,
                            userInfo: [NSLocalizedDescriptionKey: "Unexpected share URL payload."]
                        )
                    )
                }
            }
        }
    }

    private static func loadTextObject(from provider: NSItemProvider) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: NSString.self) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let item = item as? NSString {
                    continuation.resume(returning: item as String)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: NSCocoaErrorDomain,
                            code: NSFeatureUnsupportedError,
                            userInfo: [NSLocalizedDescriptionKey: "Unexpected share text payload."]
                        )
                    )
                }
            }
        }
    }

    nonisolated private static func stringValue(from item: NSSecureCoding?) -> String? {
        if let url = item as? URL {
            return url.absoluteString
        }

        if let url = item as? NSURL {
            return (url as URL).absoluteString
        }

        if let text = item as? String {
            return text
        }

        if let text = item as? NSString {
            return text as String
        }

        if let attributedText = item as? NSAttributedString {
            return attributedText.string
        }

        return nil
    }

    nonisolated private static func trimmed(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
