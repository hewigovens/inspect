import Foundation
import UniformTypeIdentifiers

@MainActor
public enum ExtensionInputExtractor {
    nonisolated private static let safariPreprocessingResultsKey = "NSExtensionJavaScriptPreprocessingResultsKey"

    public static func loadURL(from context: NSExtensionContext?) async -> URL? {
        guard let input = await loadInputString(from: context) else {
            return nil
        }

        return try? URLInputNormalizer.normalize(input: input)
    }

    public static func loadInputString(from context: NSExtensionContext?) async -> String? {
        guard let items = context?.inputItems as? [NSExtensionItem] else {
            return nil
        }

        if let value = await loadSafariPreprocessingInput(from: items) {
            return value
        }

        if let value = await loadURLLikeInput(from: items) {
            return value
        }

        if let value = await loadTextLikeInput(from: items) {
            return value
        }

        return loadAttributedFallback(from: items)
    }

    private static func loadSafariPreprocessingInput(from items: [NSExtensionItem]) async -> String? {
        for item in items {
            for provider in item.attachments ?? []
            where provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                if let payload = await loadSafariPreprocessingPayload(from: provider),
                   let urlString = stringValue(in: payload, keys: ["url", "URL"]) {
                    return urlString
                }
            }
        }

        return nil
    }

    private static func loadURLLikeInput(from items: [NSExtensionItem]) async -> String? {
        for item in items {
            for provider in item.attachments ?? [] {
                if let value = try? await loadURLObjectString(from: provider) {
                    return trimmed(value)
                }

                for typeIdentifier in [
                    UTType.url.identifier,
                    UTType.fileURL.identifier
                ] where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                    if let value = await loadItemString(from: provider, typeIdentifier: typeIdentifier) {
                        return trimmed(value)
                    }
                }
            }
        }

        return nil
    }

    private static func loadTextLikeInput(from items: [NSExtensionItem]) async -> String? {
        for item in items {
            for provider in item.attachments ?? [] {
                if let value = try? await loadTextObjectString(from: provider) {
                    return trimmed(value)
                }

                for typeIdentifier in [
                    UTType.plainText.identifier,
                    UTType.text.identifier
                ] where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                    if let value = await loadItemString(from: provider, typeIdentifier: typeIdentifier) {
                        return trimmed(value)
                    }
                }
            }
        }

        return nil
    }

    private static func loadAttributedFallback(from items: [NSExtensionItem]) -> String? {
        for item in items {
            if let body = item.attributedContentText?.string,
               let trimmedBody = trimmed(body) {
                return trimmedBody
            }

            if let title = item.attributedTitle?.string,
               let trimmedTitle = trimmed(title) {
                return trimmedTitle
            }
        }

        return nil
    }

    private static func loadSafariPreprocessingPayload(from provider: NSItemProvider) async -> [String: String]? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { item, _ in
                continuation.resume(returning: safariPreprocessingPayload(from: item))
            }
        }
    }

    nonisolated private static func safariPreprocessingPayload(from item: NSSecureCoding?) -> [String: String]? {
        if let dictionary = item as? [String: Any] {
            if let nested = dictionary[safariPreprocessingResultsKey] as? [String: Any] {
                return stringDictionary(from: nested)
            }

            return stringDictionary(from: dictionary)
        }

        if let dictionary = item as? NSDictionary {
            let bridged = dictionary as? [String: Any] ?? [:]
            if let nested = bridged[safariPreprocessingResultsKey] as? [String: Any] {
                return stringDictionary(from: nested)
            }

            return stringDictionary(from: bridged)
        }

        return nil
    }

    nonisolated private static func stringDictionary(from dictionary: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in dictionary {
            if let stringValue = value as? String {
                result[key] = stringValue
            } else if let stringValue = value as? NSString {
                result[key] = stringValue as String
            }
        }

        return result
    }

    nonisolated private static func stringValue(in dictionary: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key],
               let trimmedValue = trimmed(value) {
                return trimmedValue
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

    private static func loadURLObjectString(from provider: NSItemProvider) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: NSURL.self) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let item = item as? NSURL {
                    continuation.resume(returning: item.absoluteString ?? (item as URL).absoluteString)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: NSCocoaErrorDomain,
                            code: NSFeatureUnsupportedError,
                            userInfo: [NSLocalizedDescriptionKey: "Unexpected extension input payload."]
                        )
                    )
                }
            }
        }
    }

    private static func loadTextObjectString(from provider: NSItemProvider) async throws -> String {
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
                            userInfo: [NSLocalizedDescriptionKey: "Unexpected extension input payload."]
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
