import Foundation
import InspectCore

struct InspectMacTunnelSmokeTranscriptStore {
    let fileURL: URL

    init(fileURL: URL = Self.makeFileURL()) {
        self.fileURL = fileURL
    }

    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func append(_ text: String) {
        guard let data = text.data(using: .utf8) else {
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

    static func makeFileURL() -> URL {
        if let containerURL = InspectSharedContainer.containerURL() {
            return containerURL.appendingPathComponent("mac-smoke-test.log")
        }

        return FileManager.default.temporaryDirectory.appendingPathComponent("InspectMacSmokeTest.log")
    }
}
