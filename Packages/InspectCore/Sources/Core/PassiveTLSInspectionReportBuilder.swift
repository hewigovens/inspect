import Foundation
import Security

public struct PassiveTLSInspectionReportBuilder: Sendable {
    private let parser = CertificateParser()
    private let securityAnalyzer = SecurityAnalyzer()

    public init() {}

    public func build(from observation: TLSFlowObservation) -> TLSInspectionReport? {
        guard let certificateChainDER = observation.capturedCertificateChainDER,
              certificateChainDER.isEmpty == false,
              let host = observation.passiveInspectionHost,
              let requestedURL = makeRequestedURL(host: host, port: observation.remotePort) else {
            return nil
        }

        let secCertificates = certificateChainDER.compactMap {
            SecCertificateCreateWithData(nil, $0 as CFData)
        }
        guard secCertificates.isEmpty == false else {
            return nil
        }

        let trust = evaluateTrust(for: host, certificates: secCertificates)
        let certificates = parser.parse(certificates: secCertificates)
        let security = securityAnalyzer.analyze(
            requestedURL: requestedURL,
            trust: trust,
            certificates: certificates
        )

        return TLSInspectionReport(
            requestedURL: requestedURL,
            host: host,
            networkProtocolName: observation.negotiatedProtocol,
            trust: trust,
            security: security,
            certificates: certificates
        )
    }

    private func evaluateTrust(for host: String, certificates: [SecCertificate]) -> TrustSummary {
        let policy = SecPolicyCreateSSL(true, host as CFString)
        let input: CFTypeRef = certificates.count == 1
            ? certificates[0]
            : certificates as CFArray

        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(input, policy, &trust)
        guard status == errSecSuccess, let trust else {
            return TrustSummary(
                evaluated: false,
                isTrusted: false,
                failureReason: "Unable to construct trust object from captured certificate chain."
            )
        }

        var error: CFError?
        let isTrusted = SecTrustEvaluateWithError(trust, &error)
        return TrustSummary(
            evaluated: true,
            isTrusted: isTrusted,
            failureReason: (error as Error?)?.localizedDescription
        )
    }

    private func makeRequestedURL(host: String, port: Int?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host

        if let port, port > 0, port != 443 {
            components.port = port
        }

        return components.url
    }
}
