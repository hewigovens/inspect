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

    public static func submitInput(_ input: String) {
        submit(.input(input))
    }

    public static func submitReport(_ report: TLSInspectionReport, opensCertificateDetail: Bool) {
        submit(.report(report, opensCertificateDetail: opensCertificateDetail))
    }

    public static func consumePendingRequest() -> InspectionExternalRequest? {
        defer {
            pendingRequest = nil
        }

        return pendingRequest
    }
}

public enum InspectionExternalRequest: Sendable, Equatable {
    case input(String)
    case report(TLSInspectionReport, opensCertificateDetail: Bool)
}
