import Foundation

public enum InspectSharedLog {
    public static let fileName = "tunnel.log"

    public static func append(scope: String, message: String) {
        guard let fileURL = logFileURL() else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(scope)] \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: fileURL.path),
           let handle = try? FileHandle(forWritingTo: fileURL) {
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                try? handle.close()
            }
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public static func readTail(maxBytes: Int = 256 * 1024) -> String? {
        guard let fileURL = logFileURL(),
              let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer {
            try? handle.close()
        }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        guard fileSize > 0 else {
            return nil
        }

        if fileSize > UInt64(maxBytes) {
            try? handle.seek(toOffset: fileSize - UInt64(maxBytes))
            guard let data = try? handle.readToEnd(),
                  let raw = String(data: data, encoding: .utf8) else {
                return nil
            }

            if let firstNewline = raw.firstIndex(of: "\n") {
                let trimmed = String(raw[raw.index(after: firstNewline)...])
                return trimmed.isEmpty ? nil : trimmed
            }

            return raw.isEmpty ? nil : raw
        }

        try? handle.seek(toOffset: 0)
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8),
              text.isEmpty == false else {
            return nil
        }

        return text
    }

    public static func reset() {
        guard let fileURL = logFileURL() else {
            return
        }

        try? FileManager.default.removeItem(at: fileURL)
    }

    public static func logFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: InspectSharedContainer.appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}
