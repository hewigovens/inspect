import Foundation
import Security

public final class TLSInspector {
    private let parser = CertificateParser()

    public init() {}

    public func inspect(input: String) async throws -> TLSInspectionReport {
        try await inspect(url: URLInputNormalizer.normalize(input: input))
    }

    public func inspect(url: URL) async throws -> TLSInspectionReport {
        try await RequestRunner(url: URLInputNormalizer.normalize(url: url), parser: parser).run()
    }
}

private final class RequestRunner: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let url: URL
    private let parser: CertificateParser

    private var session: URLSession?
    private var continuation: CheckedContinuation<TLSInspectionReport, Error>?
    private var capturedTrust: SecTrust?
    private var trustEvaluationSucceeded = false
    private var trustFailureReason: String?
    private var networkProtocolName: String?
    private var tlsVersion: String?
    private var cipherSuite: String?
    private var hasCompleted = false

    init(url: URL, parser: CertificateParser) {
        self.url = url
        self.parser = parser
    }

    func run() async throws -> TLSInspectionReport {
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
        guard let transaction = metrics.transactionMetrics.last else { return }
        networkProtocolName = transaction.networkProtocolName
        tlsVersion = transaction.negotiatedTLSProtocolVersion.map(Self.tlsVersionName)
        cipherSuite = transaction.negotiatedTLSCipherSuite.map(Self.cipherSuiteName)
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

    static func cipherSuiteName(_ suite: tls_ciphersuite_t) -> String {
        switch suite {
        case .RSA_WITH_AES_128_GCM_SHA256: return "RSA AES-128-GCM SHA256"
        case .RSA_WITH_AES_256_GCM_SHA384: return "RSA AES-256-GCM SHA384"
        case .ECDHE_RSA_WITH_AES_128_GCM_SHA256: return "ECDHE-RSA AES-128-GCM SHA256"
        case .ECDHE_RSA_WITH_AES_256_GCM_SHA384: return "ECDHE-RSA AES-256-GCM SHA384"
        case .ECDHE_ECDSA_WITH_AES_128_GCM_SHA256: return "ECDHE-ECDSA AES-128-GCM SHA256"
        case .ECDHE_ECDSA_WITH_AES_256_GCM_SHA384: return "ECDHE-ECDSA AES-256-GCM SHA384"
        case .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256: return "ECDHE-RSA ChaCha20-Poly1305"
        case .ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256: return "ECDHE-ECDSA ChaCha20-Poly1305"
        case .AES_128_GCM_SHA256: return "AES-128-GCM SHA256"
        case .AES_256_GCM_SHA384: return "AES-256-GCM SHA384"
        case .CHACHA20_POLY1305_SHA256: return "ChaCha20-Poly1305 SHA256"
        default: return "0x\(String(suite.rawValue, radix: 16, uppercase: true))"
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
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
            continuation?.resume(throwing: error ?? InspectionError.missingServerTrust)
            continuation = nil
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

        let report = TLSInspectionReport(
            requestedURL: url,
            host: url.host ?? url.absoluteString,
            networkProtocolName: networkProtocolName,
            tlsVersion: tlsVersion,
            cipherSuite: cipherSuite,
            trust: trustSummary,
            security: security,
            certificates: certificates
        )

        continuation?.resume(returning: report)
        continuation = nil
    }
}
