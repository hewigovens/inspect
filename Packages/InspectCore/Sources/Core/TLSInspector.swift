import Foundation
import Security

public final class TLSInspector {
    private let parser = CertificateParser()

    public init() {}

    public func inspect(input: String) async throws -> TLSInspection {
        try await inspect(url: URLInputNormalizer.normalize(input: input))
    }

    public func inspect(url: URL) async throws -> TLSInspection {
        try await RequestRunner(url: URLInputNormalizer.normalize(url: url), parser: parser).run()
    }
}

private final class RequestRunner: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private struct CapturedTrustEvent {
        let requestURL: URL?
        let host: String
        let trust: SecTrust
        let trustEvaluationSucceeded: Bool
        let trustFailureReason: String?
    }

    private let url: URL
    private let parser: CertificateParser

    private var session: URLSession?
    private var continuation: CheckedContinuation<TLSInspection, Error>?
    private var capturedTrustEvents: [CapturedTrustEvent] = []
    private var transactionMetrics: [URLSessionTaskTransactionMetrics] = []
    private var hasCompleted = false

    init(url: URL, parser: CertificateParser) {
        self.url = url
        self.parser = parser
    }

    func run() async throws -> TLSInspection {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

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
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var error: CFError?
        let trustEvaluationSucceeded = SecTrustEvaluateWithError(serverTrust, &error)
        let trustFailureReason = (error as Error?)?.localizedDescription
        capturedTrustEvents.append(
            CapturedTrustEvent(
                requestURL: task.currentRequest?.url ?? task.originalRequest?.url,
                host: challenge.protectionSpace.host,
                trust: serverTrust,
                trustEvaluationSucceeded: trustEvaluationSucceeded,
                trustFailureReason: trustFailureReason
            )
        )

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }

    func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        transactionMetrics = metrics.transactionMetrics.filter { transaction in
            transaction.request.url?.scheme?.caseInsensitiveCompare("https") == .orderedSame
        }
    }

    static func tlsVersionName(_ version: tls_protocol_version_t) -> String {
        switch version {
        case .TLSv10: return "TLS 1.0"
        case .TLSv11: return "TLS 1.1"
        case .TLSv12: return "TLS 1.2"
        case .TLSv13: return "TLS 1.3"
        case .DTLSv10: return "DTLS 1.0"
        case .DTLSv12: return "DTLS 1.2"
        default: return "TLS (0x\(String(version.rawValue, radix: 16)))"
        }
    }

    private static let cipherSuiteNames: [tls_ciphersuite_t: String] = [
        .RSA_WITH_AES_128_GCM_SHA256: "RSA AES-128-GCM SHA256",
        .RSA_WITH_AES_256_GCM_SHA384: "RSA AES-256-GCM SHA384",
        .ECDHE_RSA_WITH_AES_128_GCM_SHA256: "ECDHE-RSA AES-128-GCM SHA256",
        .ECDHE_RSA_WITH_AES_256_GCM_SHA384: "ECDHE-RSA AES-256-GCM SHA384",
        .ECDHE_ECDSA_WITH_AES_128_GCM_SHA256: "ECDHE-ECDSA AES-128-GCM SHA256",
        .ECDHE_ECDSA_WITH_AES_256_GCM_SHA384: "ECDHE-ECDSA AES-256-GCM SHA384",
        .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256: "ECDHE-RSA ChaCha20-Poly1305",
        .ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256: "ECDHE-ECDSA ChaCha20-Poly1305",
        .AES_128_GCM_SHA256: "AES-128-GCM SHA256",
        .AES_256_GCM_SHA384: "AES-256-GCM SHA384",
        .CHACHA20_POLY1305_SHA256: "ChaCha20-Poly1305 SHA256",
    ]

    static func cipherSuiteName(_ suite: tls_ciphersuite_t) -> String {
        cipherSuiteNames[suite] ?? "0x\(String(suite.rawValue, radix: 16, uppercase: true))"
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive _: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive _: Data) {}

    func urlSession(_ session: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        guard hasCompleted == false else {
            return
        }

        hasCompleted = true
        defer {
            session.finishTasksAndInvalidate()
        }

        let reports = buildReports()
        guard !reports.isEmpty else {
            continuation?.resume(throwing: error ?? InspectionError.missingServerTrust)
            continuation = nil
            return
        }

        let inspection = TLSInspection(
            requestedURL: url,
            reports: reports
        )

        continuation?.resume(returning: inspection)
        continuation = nil
    }

    private func buildReports() -> [TLSInspectionReport] {
        // Match trust events to transactions by host rather than index.
        // URLSession may skip TLS challenges on connection reuse, so
        // index-based pairing can pair the wrong metadata with a host.
        var metricsByHost: [String: [URLSessionTaskTransactionMetrics]] = [:]
        for metric in transactionMetrics {
            if let host = metric.request.url?.host?.lowercased() {
                metricsByHost[host, default: []].append(metric)
            }
        }

        return capturedTrustEvents.compactMap { event in
            let hostKey = event.host.lowercased()
            let transaction = metricsByHost[hostKey]?.first
            if transaction != nil {
                metricsByHost[hostKey]?.removeFirst()
            }
            let requestURL = transaction?.request.url ?? event.requestURL ?? makeFallbackURL(host: event.host)
            guard let requestURL else {
                return nil
            }

            let chain = (SecTrustCopyCertificateChain(event.trust) as? [SecCertificate]) ?? []
            let certificates = parser.parse(certificates: chain)
            let trustSummary = TrustSummary(
                evaluated: true,
                isTrusted: event.trustEvaluationSucceeded,
                failureReason: event.trustFailureReason
            )
            let security = SecurityAnalyzer().analyze(
                requestedURL: requestURL,
                trust: trustSummary,
                certificates: certificates
            )

            return TLSInspectionReport(
                requestedURL: requestURL,
                host: requestURL.host ?? event.host,
                networkProtocolName: transaction?.networkProtocolName,
                tlsVersion: transaction?.negotiatedTLSProtocolVersion.map(Self.tlsVersionName),
                cipherSuite: transaction?.negotiatedTLSCipherSuite.map(Self.cipherSuiteName),
                trust: trustSummary,
                security: security,
                certificates: certificates
            )
        }
    }

    private func makeFallbackURL(host: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        return components.url
    }
}
