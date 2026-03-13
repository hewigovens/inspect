import Foundation

enum AppLinks {
    static let appStore = URL(string: "https://apps.apple.com/us/app/inspect-view-tls-certificate/id1074957486")
    static let about = URL(string: "https://fourplexlabs.github.io/Inspect/about.html")
}

enum InspectionAppMetadata {
    static var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
