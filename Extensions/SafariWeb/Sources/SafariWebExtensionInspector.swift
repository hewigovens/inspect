import Foundation
import InspectCore
import Security

final class SafariExtensionInspector {
    private let parser = CertificateParser()

    func inspect(
        input: String,
        completion: @escaping (Result<TLSInspectionReport, Error>) -> Void
    ) throws {
        let url = try URLInputNormalizer.normalize(input: input)
        SafariExtensionRequestRunner(url: url, parser: parser, completion: completion).start()
    }
}

private final class SafariExtensionRequestRunner: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
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
