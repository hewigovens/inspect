import Foundation

public enum InspectionAppMetadata {
    public static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Dev"
    }

    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    public static var versionText: String {
        "Version \(versionBuildText)"
    }

    public static var versionBuildText: String {
        "\(version) (\(build))"
    }
}
