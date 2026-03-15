import Foundation
import InspectCore
import UniformTypeIdentifiers

enum ActionExtensionInputLoader {
    private static let safariPreprocessingResultsKey = "NSExtensionJavaScriptPreprocessingResultsKey"

    static func loadURL(
        from context: NSExtensionContext?,
        logger: InspectRuntimeLogger
    ) async -> URL? {
        guard let items = context?.inputItems as? [NSExtensionItem] else {
            logger.critical("action request inputItems were unavailable")
            return nil
        }

        logger.critical("action request received \(items.count) extension item(s)")

        for (itemIndex, item) in items.enumerated() {
            let providers = item.attachments ?? []
            logger.critical(
                "action item \(itemIndex) has \(providers.count) attachment(s)"
            )

            for (providerIndex, provider) in providers.enumerated() {
                logger.critical(
                    "action item \(itemIndex) provider \(providerIndex) types: \(provider.registeredTypeIdentifiers.joined(separator: ", "))"
                )
            }
        }

        for item in items {
            for provider in item.attachments ?? []
            where provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                if let url = await loadSafariPreprocessingURL(from: provider, logger: logger) {
                    logger.critical("action request extracted Safari webpage URL input: \(url.absoluteString)")
                    return url
                }
            }
        }

        for item in items {
            for provider in item.attachments ?? []
            where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = await loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
                    logger.critical("action request extracted URL input: \(url.absoluteString)")
                    return url
                }
            }
        }

        for item in items {
            for provider in item.attachments ?? []
            where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let url = await loadURL(from: provider, typeIdentifier: UTType.plainText.identifier) {
                    logger.critical("action request extracted plain-text URL input: \(url.absoluteString)")
                    return url
                }
            }
        }

        logger.critical("action request did not yield a usable URL input")
        return nil
    }

    private static func loadSafariPreprocessingURL(
        from provider: NSItemProvider,
        logger: InspectRuntimeLogger
    ) async -> URL? {
        guard let payload = await loadSafariPreprocessingPayload(from: provider) else {
            logger.critical("action request Safari preprocessing payload was unavailable")
            return nil
        }

        logger.critical(
            "action request Safari preprocessing keys: \(payload.keys.sorted().joined(separator: ", "))"
        )

        guard let urlString = stringValue(in: payload, keys: ["url", "URL"]) else {
            return nil
        }

        return URL(string: urlString)
    }

    private static func loadSafariPreprocessingPayload(from provider: NSItemProvider) async -> [String: String]? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { item, _ in
                continuation.resume(returning: safariPreprocessingPayload(from: item))
            }
        }
    }

    private static func safariPreprocessingPayload(from item: NSSecureCoding?) -> [String: String]? {
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

    private static func stringDictionary(from dictionary: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in dictionary {
            if let value = value as? String {
                result[key] = value
            } else if let value = value as? NSString {
                result[key] = value as String
            }
        }

        return result
    }

    private static func stringValue(in dictionary: [String: String], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return trimmed
                }
            }
        }

        return nil
    }

    private static func loadURL(from provider: NSItemProvider, typeIdentifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                    return
                }

                if let text = item as? String {
                    continuation.resume(returning: URL(string: text))
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }
}
