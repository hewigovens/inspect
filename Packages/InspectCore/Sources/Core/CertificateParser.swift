import CryptoKit
import Foundation
import Security
import X509

public struct CertificateParser: Sendable {
    public init() {}

    public func parse(certificates: [SecCertificate]) -> [CertificateDetails] {
        certificates.enumerated().map { index, certificate in
            parse(certificate: certificate, index: index, totalCount: certificates.count)
        }
    }

    public func parse(certificate: SecCertificate, index: Int, totalCount: Int) -> CertificateDetails {
        let derData = SecCertificateCopyData(certificate) as Data

        guard let parsedCertificate = try? X509.Certificate(certificate) else {
            return fallbackCertificate(
                secCertificate: certificate,
                derData: derData,
                index: index,
                totalCount: totalCount
            )
        }

        let subject = parse(distinguishedName: parsedCertificate.subject)
        let issuer = parse(distinguishedName: parsedCertificate.issuer)
        let publicKey = parsePublicKey(parsedCertificate.publicKey, secCertificate: certificate)
        let keyUsage = parseKeyUsage(parsedCertificate)
        let extendedKeyUsage = parseExtendedKeyUsage(parsedCertificate)
        let policies = CustomExtensionDecoders.certificatePolicies(from: parsedCertificate)
        let subjectKeyIdentifier = parseSubjectKeyIdentifier(parsedCertificate)
        let authorityKeyIdentifier = parseAuthorityKeyIdentifier(parsedCertificate)

        return CertificateDetails(
            id: SHA256.hash(data: derData).inspectHexString,
            title: SecCertificateCopySubjectSummary(certificate) as String? ?? subject.first?.value ?? "Certificate",
            isLeaf: index == 0,
            isRoot: index == totalCount - 1,
            subject: subject,
            issuer: issuer,
            validity: ValidityPeriod(
                notBefore: parsedCertificate.notValidBefore,
                notAfter: parsedCertificate.notValidAfter
            ),
            serialNumber: Array(parsedCertificate.serialNumber.bytes).inspectHexString(grouped: true),
            version: String(describing: parsedCertificate.version),
            signatureAlgorithm: normalizeSignatureAlgorithm(String(describing: parsedCertificate.signatureAlgorithm)),
            signature: parsedCertificate.signature.rawRepresentation.inspectHexString(grouped: true),
            publicKey: publicKey,
            keyUsage: keyUsage,
            extendedKeyUsage: extendedKeyUsage,
            fingerprints: fingerprints(for: derData),
            subjectAlternativeNames: parseSubjectAlternativeNames(parsedCertificate),
            policies: policies,
            subjectKeyIdentifier: subjectKeyIdentifier,
            authorityKeyIdentifier: authorityKeyIdentifier,
            authorityInfoAccess: parseAuthorityInfoAccess(parsedCertificate),
            basicConstraints: parseBasicConstraints(parsedCertificate),
            extensions: parseExtensions(parsedCertificate),
            derData: derData
        )
    }

    private func fallbackCertificate(
        secCertificate: SecCertificate,
        derData: Data,
        index: Int,
        totalCount: Int
    ) -> CertificateDetails {
        let title = SecCertificateCopySubjectSummary(secCertificate) as String? ?? "Certificate"

        return CertificateDetails(
            id: SHA256.hash(data: derData).inspectHexString,
            title: title,
            isLeaf: index == 0,
            isRoot: index == totalCount - 1,
            subject: [LabeledValue(label: "Common Name", value: title)],
            issuer: [],
            validity: ValidityPeriod(notBefore: nil, notAfter: nil),
            serialNumber: "Unavailable",
            version: "Unavailable",
            signatureAlgorithm: "Unavailable",
            signature: "Unavailable",
            publicKey: parsePublicKey(nil, secCertificate: secCertificate),
            keyUsage: [],
            extendedKeyUsage: [],
            fingerprints: fingerprints(for: derData),
            subjectAlternativeNames: [],
            policies: [],
            subjectKeyIdentifier: nil,
            authorityKeyIdentifier: [],
            authorityInfoAccess: [],
            basicConstraints: [],
            extensions: [],
            derData: derData
        )
    }

    private func parse(distinguishedName: DistinguishedName) -> [LabeledValue] {
        distinguishedName.flatMap { relativeName in
            relativeName.compactMap { attribute in
                parse(attribute: attribute)
            }
        }
    }

    private func parse(attribute: RelativeDistinguishedName.Attribute) -> LabeledValue? {
        let rendered = String(describing: attribute)
        guard let separatorIndex = rendered.firstIndex(of: "=") else {
            return nil
        }

        let rawLabel = String(rendered[..<separatorIndex])
        let value = String(rendered[rendered.index(after: separatorIndex)...])
        return LabeledValue(label: distinguishedNameLabel(for: rawLabel), value: value)
    }

    private func parseSubjectAlternativeNames(_ certificate: X509.Certificate) -> [LabeledValue] {
        guard let names = try? certificate.extensions.subjectAlternativeNames else {
            return []
        }

        return names.map(parse(generalName:))
    }

    private func parseAuthorityInfoAccess(_ certificate: X509.Certificate) -> [LabeledValue] {
        guard let accessDescriptions = try? certificate.extensions.authorityInformationAccess else {
            return []
        }

        return accessDescriptions.map { description in
            LabeledValue(
                label: String(describing: description.method),
                value: displayValue(for: description.location)
            )
        }
    }

    private func parseBasicConstraints(_ certificate: X509.Certificate) -> [LabeledValue] {
        guard let constraints = try? certificate.extensions.basicConstraints else {
            return []
        }

        switch constraints {
        case .notCertificateAuthority:
            return [LabeledValue(label: "Certificate Authority", value: "No")]
        case .isCertificateAuthority(let maxPathLength):
            if let maxPathLength {
                return [
                    LabeledValue(label: "Certificate Authority", value: "Yes"),
                    LabeledValue(label: "Max Path Length", value: String(maxPathLength))
                ]
            }

            return [LabeledValue(label: "Certificate Authority", value: "Yes")]
        }
    }

    private func parseKeyUsage(_ certificate: X509.Certificate) -> [String] {
        guard let usage = try? certificate.extensions.keyUsage else {
            return []
        }

        return String(describing: usage)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func parseExtendedKeyUsage(_ certificate: X509.Certificate) -> [String] {
        guard let usage = try? certificate.extensions.extendedKeyUsage else {
            return []
        }

        return usage.map { normalizeExtendedKeyUsage(String(describing: $0)) }
    }

    private func parseSubjectKeyIdentifier(_ certificate: X509.Certificate) -> String? {
        guard let identifier = try? certificate.extensions.subjectKeyIdentifier else {
            return nil
        }

        return Array(identifier.keyIdentifier).inspectHexString(grouped: true)
    }

    private func parseAuthorityKeyIdentifier(_ certificate: X509.Certificate) -> [LabeledValue] {
        guard let identifier = try? certificate.extensions.authorityKeyIdentifier else {
            return []
        }

        var entries: [LabeledValue] = []

        if let keyIdentifier = identifier.keyIdentifier {
            entries.append(LabeledValue(label: "Key Identifier", value: Array(keyIdentifier).inspectHexString(grouped: true)))
        }

        if let issuerNames = identifier.authorityCertIssuer {
            for (index, issuer) in issuerNames.enumerated() {
                entries.append(LabeledValue(label: "Issuer #\(index + 1)", value: displayValue(for: issuer)))
            }
        }

        if let serial = identifier.authorityCertSerialNumber {
            entries.append(LabeledValue(
                label: "Issuer Serial",
                value: Array(serial.bytes).inspectHexString(grouped: true)
            ))
        }

        return entries
    }

    private func parseExtensions(_ certificate: X509.Certificate) -> [LabeledValue] {
        certificate.extensions.map { ext in
            let label = extensionLabel(for: ext)
            let value = extensionValue(for: ext)
            return LabeledValue(label: label, value: value)
        }
    }

    private func extensionLabel(for ext: X509.Certificate.Extension) -> String {
        let base = extensionFriendlyName(for: String(describing: ext.oid))
        return ext.critical ? "\(base) (critical)" : base
    }

    private func extensionValue(for ext: X509.Certificate.Extension) -> String {
        if let decoded = try? SubjectAlternativeNames(ext) {
            return decoded.map(displayValue(for:)).joined(separator: ", ")
        }

        if let decoded = try? AuthorityInformationAccess(ext) {
            return decoded.map { "\(String(describing: $0.method)): \(displayValue(for: $0.location))" }
                .joined(separator: ", ")
        }

        if let decoded = try? BasicConstraints(ext) {
            return String(describing: decoded)
        }

        if let decoded = try? SubjectKeyIdentifier(ext) {
            return Array(decoded.keyIdentifier).inspectHexString(grouped: true)
        }

        if let decoded = try? AuthorityKeyIdentifier(ext) {
            var parts: [String] = []

            if let keyIdentifier = decoded.keyIdentifier {
                parts.append("keyID: \(Array(keyIdentifier).inspectHexString(grouped: true))")
            }

            if let serial = decoded.authorityCertSerialNumber {
                parts.append("issuerSerial: \(Array(serial.bytes).inspectHexString(grouped: true))")
            }

            if let issuer = decoded.authorityCertIssuer {
                parts.append("issuer: \(issuer.map(displayValue(for:)).joined(separator: ", "))")
            }

            return parts.joined(separator: ", ")
        }

        if let decoded = try? ExtendedKeyUsage(ext) {
            return decoded.map { normalizeExtendedKeyUsage(String(describing: $0)) }.joined(separator: ", ")
        }

        if let decoded = try? KeyUsage(ext) {
            return String(describing: decoded)
        }

        if ext.oid == [2, 5, 29, 32] {
            let decoded = CustomExtensionDecoders.certificatePolicies(from: ext)
            return decoded.map { "\($0.label): \($0.value)" }.joined(separator: ", ")
        }

        return Array(ext.value).inspectHexString(grouped: true)
    }

    private func parsePublicKey(_ publicKey: X509.Certificate.PublicKey?, secCertificate: SecCertificate) -> PublicKeyDetails {
        let fallbackHex = publicKey.map { Array($0.subjectPublicKeyInfoBytes).inspectHexString(grouped: true) } ?? "Unavailable"
        let description = publicKey.map { String(describing: $0) } ?? "Unavailable"
        let fallbackKeyInfo = parsePublicKeyDescription(description)
        let spkiFingerprint = publicKey.map {
            SHA256.hash(data: Data($0.subjectPublicKeyInfoBytes)).inspectHexString(grouped: true)
        } ?? "Unavailable"

        guard let secKey = SecCertificateCopyKey(secCertificate) else {
            return PublicKeyDetails(
                algorithm: fallbackKeyInfo.algorithm,
                bitSize: fallbackKeyInfo.bitSize,
                hexRepresentation: fallbackHex,
                spkiSHA256Fingerprint: spkiFingerprint
            )
        }

        let attributes = SecKeyCopyAttributes(secKey) as NSDictionary? ?? [:]
        let keyData = attributes[kSecValueData] as? Data
        let bitSize = (attributes[kSecAttrKeySizeInBits] as? NSNumber)?.intValue ?? fallbackKeyInfo.bitSize

        return PublicKeyDetails(
            algorithm: fallbackKeyInfo.algorithm,
            bitSize: bitSize,
            hexRepresentation: keyData?.inspectHexString(grouped: true) ?? fallbackHex,
            spkiSHA256Fingerprint: spkiFingerprint
        )
    }

    private func parsePublicKeyDescription(_ description: String) -> (algorithm: String, bitSize: Int?) {
        if let match = description.firstMatch(of: /RSA(\d+)\.PublicKey/),
           let bitSize = Int(match.1) {
            return ("RSA", bitSize)
        }

        if description == "P256.PublicKey" {
            return ("P-256", 256)
        }

        if description == "P384.PublicKey" {
            return ("P-384", 384)
        }

        if description == "P521.PublicKey" {
            return ("P-521", 521)
        }

        if description == "Ed25519.PublicKey" {
            return ("Ed25519", 255)
        }

        return (description.replacingOccurrences(of: ".PublicKey", with: ""), nil)
    }

    private func parse(generalName: GeneralName) -> LabeledValue {
        switch generalName {
        case .dnsName(let value):
            return LabeledValue(label: "DNS Name", value: value)
        case .rfc822Name(let value):
            return LabeledValue(label: "Email", value: value)
        case .uniformResourceIdentifier(let value):
            return LabeledValue(label: "URI", value: value)
        case .ipAddress(let value):
            return LabeledValue(label: "IP Address", value: formatIPAddress(value.bytes))
        case .directoryName(let value):
            return LabeledValue(label: "Directory Name", value: String(describing: value))
        case .registeredID(let value):
            return LabeledValue(label: "Registered ID", value: String(describing: value))
        case .otherName(let value):
            return LabeledValue(label: "Other Name", value: String(describing: value))
        case .x400Address(let value):
            return LabeledValue(label: "X.400 Address", value: String(describing: value))
        case .ediPartyName(let value):
            return LabeledValue(label: "EDI Party", value: String(describing: value))
        }
    }

    private func displayValue(for generalName: GeneralName) -> String {
        parse(generalName: generalName).value
    }

    private func formatIPAddress(_ bytes: ArraySlice<UInt8>) -> String {
        switch bytes.count {
        case 4:
            return bytes.map(String.init).joined(separator: ".")
        case 16:
            return stride(from: bytes.startIndex, to: bytes.endIndex, by: 2)
                .map { index in
                    let high = UInt16(bytes[index]) << 8
                    let low = UInt16(bytes[bytes.index(after: index)])
                    return String(high | low, radix: 16)
                }
                .joined(separator: ":")
        default:
            return Array(bytes).inspectHexString(grouped: true)
        }
    }

    private func fingerprints(for derData: Data) -> [LabeledValue] {
        [
            LabeledValue(label: "SHA-256", value: SHA256.hash(data: derData).inspectHexString(grouped: true)),
            LabeledValue(label: "SHA-1", value: Insecure.SHA1.hash(data: derData).inspectHexString(grouped: true))
        ]
    }

    private func distinguishedNameLabel(for shortName: String) -> String {
        switch shortName {
        case "CN":
            return "Common Name"
        case "C":
            return "Country"
        case "L":
            return "Locality"
        case "ST":
            return "State/Province"
        case "O":
            return "Organization"
        case "OU":
            return "Organizational Unit"
        case "STREET":
            return "Street Address"
        case "DC":
            return "Domain Component"
        case "E":
            return "Email"
        default:
            return shortName
        }
    }

    private func extensionFriendlyName(for oid: String) -> String {
        switch oid {
        case "2.5.29.14":
            return "Subject Key Identifier"
        case "2.5.29.15":
            return "Key Usage"
        case "2.5.29.17":
            return "Subject Alternative Name"
        case "2.5.29.19":
            return "Basic Constraints"
        case "2.5.29.32":
            return "Certificate Policies"
        case "2.5.29.35":
            return "Authority Key Identifier"
        case "2.5.29.37":
            return "Extended Key Usage"
        case "1.3.6.1.5.5.7.1.1":
            return "Authority Information Access"
        default:
            return oid
        }
    }

    private func normalizeSignatureAlgorithm(_ value: String) -> String {
        switch value {
        case "SignatureAlgorithm.sha1WithRSAEncryption":
            return "SHA-1 with RSA"
        case "SignatureAlgorithm.sha256WithRSAEncryption":
            return "SHA-256 with RSA"
        case "SignatureAlgorithm.sha384WithRSAEncryption":
            return "SHA-384 with RSA"
        case "SignatureAlgorithm.sha512WithRSAEncryption":
            return "SHA-512 with RSA"
        case "SignatureAlgorithm.ecdsaWithSHA256":
            return "ECDSA with SHA-256"
        case "SignatureAlgorithm.ecdsaWithSHA384":
            return "ECDSA with SHA-384"
        case "SignatureAlgorithm.ecdsaWithSHA512":
            return "ECDSA with SHA-512"
        case "SignatureAlgorithm.ed25519":
            return "Ed25519"
        default:
            return value.replacingOccurrences(of: "SignatureAlgorithm.", with: "")
        }
    }

    private func normalizeExtendedKeyUsage(_ value: String) -> String {
        switch value {
        case "serverAuth":
            return "TLS Web Server Authentication"
        case "clientAuth":
            return "TLS Web Client Authentication"
        case "codeSigning":
            return "Code Signing"
        case "emailProtection":
            return "Email Protection"
        case "timeStamping":
            return "Time Stamping"
        case "ocspSigning":
            return "OCSP Signing"
        case "anyKeyUsage":
            return "Any Key Usage"
        case "certificateTransparency":
            return "Certificate Transparency"
        default:
            return value
        }
    }
}

private extension Data {
    var inspectHexString: String {
        inspectHexString(grouped: false)
    }

    func inspectHexString(grouped: Bool) -> String {
        let bytes = map { String(format: "%02X", $0) }
        return grouped ? bytes.joined(separator: " ") : bytes.joined()
    }
}

private extension Array where Element == UInt8 {
    func inspectHexString(grouped: Bool) -> String {
        Data(self).inspectHexString(grouped: grouped)
    }
}

private extension Digest {
    var inspectHexString: String {
        map { String(format: "%02X", $0) }.joined()
    }

    func inspectHexString(grouped: Bool) -> String {
        let bytes = map { String(format: "%02X", $0) }
        return grouped ? bytes.joined(separator: " ") : bytes.joined()
    }
}
