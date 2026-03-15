import Foundation
import InspectCore
import SafariServices
import Security

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let inspector = SafariExtensionInspector()

    func beginRequest(with context: NSExtensionContext) {
        guard let request = extensionRequest(from: context.inputItems.first as? NSExtensionItem) else {
            Self.complete(context: context, payload: Self.errorPayload("Safari sent an invalid Inspect extension request."))
            return
        }

        switch request.type {
        case "inspect-tab":
            guard let urlString = request.urlString else {
                Self.complete(context: context, payload: Self.errorPayload("The current page URL was unavailable."))
                return
            }

            do {
                try inspector.inspect(input: urlString) { result in
                    let payload: [String: Any]
                    switch result {
                    case let .success(report):
                        payload = Self.successPayload(for: report)
                    case let .failure(error):
                        payload = Self.errorPayload(error.localizedDescription)
                    }

                    Self.complete(context: context, payload: payload)
                }
            } catch {
                Self.complete(context: context, payload: Self.errorPayload(error.localizedDescription))
            }
        case "open-full-details":
            guard let token = request.reportToken else {
                Self.complete(context: context, payload: Self.errorPayload("No stored inspection was available to open."))
                return
            }

            let box = ExtensionContextBox(context)
            box.context.open(InspectDeepLink.certificateDetail(token: token).url) { success in
                Self.complete(
                    context: box.context,
                    payload: success
                        ? ["status": "opened"]
                        : Self.errorPayload("Inspect could not be opened from the Safari extension.")
                )
            }
        default:
            Self.complete(context: context, payload: Self.errorPayload("Unsupported Safari extension request: \(request.type)"))
        }
    }

    private static var messageUserInfoKey: String {
        if #available(iOS 15.0, macOS 11.0, *) {
            SFExtensionMessageKey
        } else {
            "message"
        }
    }

    private func extensionRequest(from item: NSExtensionItem?) -> ExtensionRequest? {
        guard let message = item?.userInfo?[Self.messageUserInfoKey] as? [String: Any],
              let type = message["type"] as? String else {
            return nil
        }

        return ExtensionRequest(
            type: type,
            urlString: message["url"] as? String,
            reportToken: message["reportToken"] as? String
        )
    }

    private static func complete(context: NSExtensionContext, payload: [String: Any]) {
        let response = NSExtensionItem()
        response.userInfo = [messageUserInfoKey: payload]
        let box = ExtensionCompletionBox(context: context, response: response)

        DispatchQueue.main.async {
            box.context.completeRequest(returningItems: [box.response], completionHandler: nil)
        }
    }

    private static func successPayload(for report: TLSInspectionReport) -> [String: Any] {
        let leaf = report.leafCertificate
        let reportToken = try? InspectionSharedReportStore.save(report)
        let tone: String
        if report.security.criticalCount > 0 || report.trust.isTrusted == false {
            tone = "critical"
        } else if report.security.warningCount > 0 {
            tone = "warning"
        } else {
            tone = "good"
        }

        let trustSummary = report.trust.isTrusted
            ? "The platform trust engine accepted the chain."
            : (report.trust.failureReason ?? "The platform trust engine rejected the chain.")

        return [
            "status": "success",
            "tone": tone,
            "host": report.host,
            "url": report.requestedURL.absoluteString,
            "protocolName": report.networkProtocolName ?? "Unknown",
            "trustBadge": report.trust.badgeText,
            "trustSummary": trustSummary,
            "securityHeadline": report.security.headline,
            "criticalCount": report.security.criticalCount,
            "warningCount": report.security.warningCount,
            "leafTitle": leaf?.title ?? report.host,
            "commonName": leaf?.commonNames.first ?? leaf?.subjectSummary ?? report.host,
            "issuerSummary": leaf?.issuerSummary ?? "Unknown issuer",
            "validityStatus": leaf?.validity.status.rawValue ?? "Unknown",
            "validUntil": formattedDate(leaf?.validity.notAfter),
            "reportToken": reportToken ?? "",
            "chainNames": report.certificates.map(\.subjectSummary),
            "topFindingTitle": report.security.findings.first?.title ?? "",
            "topFindingMessage": report.security.findings.first?.message ?? ""
        ]
    }

    private static func errorPayload(_ message: String) -> [String: Any] {
        [
            "status": "error",
            "message": message
        ]
    }

    private static func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "Unknown"
        }

        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }
}

private struct ExtensionRequest {
    let type: String
    let urlString: String?
    let reportToken: String?
}

private final class SafariExtensionInspector {
    private let parser = CertificateParser()

    func inspect(
        input: String,
        completion: @escaping (Result<TLSInspectionReport, Error>) -> Void
    ) throws {
        let url = try URLInputNormalizer.normalize(input: input)
        RequestRunner(url: url, parser: parser, completion: completion).start()
    }
}

private final class RequestRunner: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let url: URL
    private let parser: CertificateParser
    private let completion: (Result<TLSInspectionReport, Error>) -> Void

    private var session: URLSession?
    private var capturedTrust: SecTrust?
    private var trustEvaluationSucceeded = false
    private var trustFailureReason: String?
    private var networkProtocolName: String?
    private var hasCompleted = false

    init(
        url: URL,
        parser: CertificateParser,
        completion: @escaping (Result<TLSInspectionReport, Error>) -> Void
    ) {
        self.url = url
        self.parser = parser
        self.completion = completion
    }

    func start() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.connectionProxyDictionary = [:]

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        var request = URLRequest(url: url)
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        request.timeoutInterval = 20

        session.dataTask(with: request).resume()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        capturedTrust = serverTrust

        var error: CFError?
        trustEvaluationSucceeded = SecTrustEvaluateWithError(serverTrust, &error)
        trustFailureReason = (error as Error?)?.localizedDescription

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        networkProtocolName = metrics.transactionMetrics
            .compactMap(\.networkProtocolName)
            .last
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {}

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard hasCompleted == false else {
            return
        }

        hasCompleted = true
        defer {
            session.finishTasksAndInvalidate()
        }

        guard let trust = capturedTrust else {
            completion(.failure(error ?? InspectionError.missingServerTrust))
            return
        }

        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        let certificates = parser.parse(certificates: chain)
        let trustSummary = TrustSummary(
            evaluated: true,
            isTrusted: trustEvaluationSucceeded,
            failureReason: trustFailureReason
        )
        let security = SecurityAnalyzer().analyze(
            requestedURL: url,
            trust: trustSummary,
            certificates: certificates
        )

        completion(.success(TLSInspectionReport(
            requestedURL: url,
            host: url.host ?? url.absoluteString,
            networkProtocolName: networkProtocolName,
            trust: trustSummary,
            security: security,
            certificates: certificates
        )))
    }
}

private final class ExtensionCompletionBox: @unchecked Sendable {
    let context: NSExtensionContext
    let response: NSExtensionItem

    init(context: NSExtensionContext, response: NSExtensionItem) {
        self.context = context
        self.response = response
    }
}

private final class ExtensionContextBox: @unchecked Sendable {
    let context: NSExtensionContext

    init(_ context: NSExtensionContext) {
        self.context = context
    }
}
