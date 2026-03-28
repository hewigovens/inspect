import Foundation
import Security

public enum RevocationStatus: Sendable, Equatable {
    case unchecked
    case checking
    case good
    case revoked(String)
    case unreachable(String)
}

public enum RevocationChecker: Sendable {
    public static func check(
        certificates: [CertificateDetails],
        host: String
    ) async -> RevocationStatus {
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

        let message = (error as Error?)?.localizedDescription ?? "Evaluation failed"
        let lowered = message.lowercased()

        if lowered.contains("revoke") {
            return .revoked(message)
        }

        if lowered.contains("ocsp") || lowered.contains("crl") || lowered.contains("revocation") {
            return .unreachable(message)
        }

        return .unreachable(message)
    }
}
