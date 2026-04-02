import Foundation
import InspectCore

enum CertificateExportWriter {
    static func writeTemporaryCertificate(_ certificate: CertificateDetails, host: String, indexInChain: Int) -> URL? {
        let fileName = sanitize(host: host) + "-chain-\(indexInChain + 1).cer"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try certificate.derData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func pemString(for certificate: CertificateDetails) -> String {
        let base64 = certificate.derData.base64EncodedString(options: .lineLength64Characters)
        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----"
    }

    static func fullChainPEM(from certificates: [CertificateDetails]) -> String {
        certificates.map { pemString(for: $0) }.joined(separator: "\n")
    }

    static func sanitize(host: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let lowered = host.lowercased().replacingOccurrences(of: ".", with: "-")
        let scalars = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let raw = String(scalars)
        return raw.replacingOccurrences(of: "--", with: "-")
    }
}
