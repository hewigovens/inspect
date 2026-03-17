import Foundation
import InspectCore

@MainActor
public enum InspectionExternalInputCenter {
    public static let notification = Notification.Name("inspect.feature.external-input")

    private static var pendingRequest: InspectionExternalRequest?

    public static func submit(_ request: InspectionExternalRequest) {
        pendingRequest = request
        NotificationCenter.default.post(name: notification, object: nil)
    }

    public static func submitReport(_ report: TLSInspectionReport, opensCertificateDetail: Bool) {
        submit(.report(report, opensCertificateDetail: opensCertificateDetail))
    }

    @discardableResult
    public static func handleDeepLink(
        _ url: URL,
        prepareForNavigation: (() -> Void)? = nil
    ) -> Bool {
        guard let deepLink = InspectDeepLink(url: url) else {
            return false
        }

        switch deepLink {
        case let .certificateDetail(token):
            guard let report = InspectionSharedReportStore.consume(token: token) else {
                return false
            }

            prepareForNavigation?()
            submitReport(report, opensCertificateDetail: true)
            return true
        }
    }

    public static func consumePendingRequest() -> InspectionExternalRequest? {
        defer {
            pendingRequest = nil
        }

        return pendingRequest
    }

    public static func consumePendingSharedReportRequest() -> InspectionExternalRequest? {
        guard let token = InspectionSharedPendingReportStore.consumeToken(),
              let report = InspectionSharedReportStore.consume(token: token) else {
            return nil
        }

        return .report(report, opensCertificateDetail: true)
    }
}

public enum InspectionExternalRequest: Sendable, Equatable {
    case report(TLSInspectionReport, opensCertificateDetail: Bool)
}
