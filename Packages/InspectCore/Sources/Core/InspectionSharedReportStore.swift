import Foundation

public enum InspectionSharedReportStore {
    public static func save(_ report: TLSInspectionReport) throws -> String {
        let token = UUID().uuidString.lowercased()
        let directory = try ensureDirectory()
        let url = directory.appendingPathComponent("\(token).json")
        let data = try JSONEncoder().encode(report)
        try data.write(to: url, options: [.atomic])
        return token
    }

    public static func consume(token: String) -> TLSInspectionReport? {
        guard let url = fileURL(for: token),
              let data = try? Data(contentsOf: url),
              let report = try? JSONDecoder().decode(TLSInspectionReport.self, from: data) else {
            return nil
        }

        try? FileManager.default.removeItem(at: url)
        return report
    }

    private static func ensureDirectory() throws -> URL {
        guard let container = InspectSharedContainer.containerURL() else {
            throw InspectionError.missingSharedContainer
        }

        let directory = container
            .appendingPathComponent("pending-inspections", isDirectory: true)

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
            .appendingPathComponent("pending-inspections", isDirectory: true)
            .appendingPathComponent("\(token).json")
    }
}
