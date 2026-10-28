import Foundation
import Security

public enum RevocationStatus: Sendable, Equatable {
    case unchecked
    case checking
    case good
    case crlOnly
    case revoked(String)
    case unreachable(String)
}

public enum RevocationChecker: Sendable {
    public static func check(
        certificates: [CertificateDetails],
        host: String
    ) async -> RevocationStatus {
        let leafCertificate = certificates.first
        let secCerts = certificates.compactMap {
            SecCertificateCreateWithData(nil, $0.derData as CFData)
        }

        guard secCerts.isEmpty == false else {
            return .unreachable("No certificates available")
        }

        let sslPolicy = SecPolicyCreateSSL(true, host as CFString)
        let revocationFlags: CFOptionFlags =
            kSecRevocationOCSPMethod | kSecRevocationCRLMethod | kSecRevocationRequirePositiveResponse
        let revocationPolicy = SecPolicyCreateRevocation(revocationFlags)

        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(
            secCerts as CFArray,
            [sslPolicy, revocationPolicy] as CFArray,
            &trust
        )

        guard status == errSecSuccess, let trust else {
            return .unreachable("Failed to create trust evaluation")
        }

        SecTrustSetNetworkFetchAllowed(trust, true)

        var error: CFError?
        let passed = SecTrustEvaluateWithError(trust, &error)

        if passed {
            return .good
        }

        return failureStatus(for: leafCertificate, error: error as Error?)
    }

    static func failureStatus(
        for leafCertificate: CertificateDetails?,
        error: Error?
    ) -> RevocationStatus {
        let error = error as NSError?
        let message = error?.localizedDescription ?? "Evaluation failed"

        if error?.domain == NSOSStatusErrorDomain {
            if error?.code == Int(errSecCertificateRevoked) {
                return .revoked(message)
            }

            if error?.code == Int(errSecIncompleteCertRevocationCheck),
               let leafCertificate,
               leafCertificate.hasOCSPResponder == false,
               leafCertificate.hasCRLDistributionPoints
            {
                return .crlOnly
            }
        }

        return .unreachable(message)
    }
}
