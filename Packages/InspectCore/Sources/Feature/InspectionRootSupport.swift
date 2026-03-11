import InspectCore
import SwiftUI

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

struct InspectionCertificateRoute: Identifiable {
    let id = UUID()
    let report: TLSInspectionReport
    let initialSelectionIndex: Int
}

extension InspectionCertificateRoute: Hashable {
    static func == (lhs: InspectionCertificateRoute, rhs: InspectionCertificateRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public enum InspectionWindowLayoutPreference: String {
    case standard
    case certificateDetail
}

public enum InspectionWindowLayoutCenter {
    public static let notification = Notification.Name("inspect.feature.window-layout")

    public static func post(_ preference: InspectionWindowLayoutPreference) {
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: ["preference": preference.rawValue]
        )
    }

    public static func preference(from notification: Notification) -> InspectionWindowLayoutPreference? {
        guard let rawValue = notification.userInfo?["preference"] as? String else {
            return nil
        }

        return InspectionWindowLayoutPreference(rawValue: rawValue)
    }
}

enum RecentInputFormatter {
    static func host(for recent: String) -> String? {
        (try? URLInputNormalizer.normalize(input: recent).host) ?? URL(string: recent)?.host
    }

    static func primaryText(for recent: String) -> String {
        guard let url = try? URLInputNormalizer.normalize(input: recent) else {
            return recent
        }

        return url.host ?? recent
    }

    static func secondaryText(for recent: String) -> String? {
        guard let url = try? URLInputNormalizer.normalize(input: recent) else {
            return nil
        }

        let path = url.path == "/" ? "" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let tail = path + query
        return tail.isEmpty ? nil : tail
    }
}

struct RecentLookupItem: Identifiable, Equatable {
    let rawInput: String
    let normalizedURL: URL?
    let host: String?
    let primaryText: String
    let secondaryText: String?

    init(_ recent: String) {
        rawInput = recent
        normalizedURL = try? URLInputNormalizer.normalize(input: recent)
        host = RecentInputFormatter.host(for: recent)
        primaryText = RecentInputFormatter.primaryText(for: recent)
        secondaryText = RecentInputFormatter.secondaryText(for: recent)
    }

    var id: String {
        normalizedURL?.absoluteString ?? rawInput
    }
}

extension View {
    func inspectURLField() -> some View {
        inspectPlatformURLField()
    }

    @ViewBuilder
    func applyExtensionScrollMargins(_ presentation: InspectionPresentation) -> some View {
        if presentation == .actionExtension {
            self.contentMargins(.top, 0, for: .scrollContent)
        } else {
            self
        }
    }

    func hideRootNavigationBar() -> some View {
        inspectNavigationBarHidden()
    }

    func inlineRootNavigationTitle() -> some View {
        inspectInlineNavigationTitle()
    }

    func extensionGroupedListStyle() -> some View {
        inspectGroupedListStyle(background: InspectPlatform.groupedBackground)
    }
}

extension Font {
    static let inspectRootTitle = Font.system(size: 29, weight: .bold, design: .rounded)
    static let inspectRootTitle3 = Font.system(size: 21, weight: .bold, design: .rounded)
    static let inspectRootHeadline = Font.system(size: 18, weight: .semibold)
    static let inspectRootSubheadline = Font.system(size: 16)
    static let inspectRootSubheadlineSemibold = Font.system(size: 16, weight: .semibold)
    static let inspectRootCaption = Font.system(size: 13)
    static let inspectRootCaptionSemibold = Font.system(size: 13, weight: .semibold)
    static let inspectRootCaptionBold = Font.system(size: 13, weight: .bold)
    static let inspectRootFootnote = Font.system(size: 14)
}
