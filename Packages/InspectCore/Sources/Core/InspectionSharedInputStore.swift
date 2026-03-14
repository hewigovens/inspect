import Foundation

public enum InspectionSharedInputStore {
    private static let pendingTokensKey = "inspect.pending-input-tokens"

    public static func save(_ input: String) throws -> String {
        let token = UUID().uuidString.lowercased()
        let directory = try ensureDirectory()
        let url = directory.appendingPathComponent("\(token).txt")
        try input.write(to: url, atomically: true, encoding: .utf8)
        return token
    }

    public static func enqueue(_ input: String) throws {
        let token = try save(input)
        var tokens = sharedDefaults()?.stringArray(forKey: pendingTokensKey) ?? []
        tokens.append(token)
        sharedDefaults()?.set(tokens, forKey: pendingTokensKey)
    }

    public static func consume(token: String) -> String? {
        guard let url = fileURL(for: token),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        try? FileManager.default.removeItem(at: url)
        return value
    }

    public static func consumeNextPending() -> String? {
        guard let defaults = sharedDefaults() else {
            return nil
        }

        var tokens = defaults.stringArray(forKey: pendingTokensKey) ?? []
        guard let token = tokens.first else {
            return nil
        }

        tokens.removeFirst()
        defaults.set(tokens, forKey: pendingTokensKey)
        return consume(token: token)
    }

    private static func ensureDirectory() throws -> URL {
        guard let container = InspectSharedContainer.containerURL() else {
            throw InspectionError.missingSharedContainer
        }

        let directory = container
            .appendingPathComponent("pending-inputs", isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    private static func fileURL(for token: String) -> URL? {
        guard let container = InspectSharedContainer.containerURL() else {
            return nil
        }

        return container
            .appendingPathComponent("pending-inputs", isDirectory: true)
            .appendingPathComponent("\(token).txt")
    }

    private static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: InspectSharedContainer.appGroupIdentifier)
    }
}
