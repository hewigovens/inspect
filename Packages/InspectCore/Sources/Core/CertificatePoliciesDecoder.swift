import SwiftASN1
import X509

enum CertificatePoliciesDecoder {
    private static let oid: ASN1ObjectIdentifier = [2, 5, 29, 32]

    static func decode(from certificate: X509.Certificate) -> [LabeledValue] {
        guard let ext = certificate.extensions[oid: oid] else { return [] }
        return decode(from: ext)
    }

    static func decode(from ext: X509.Certificate.Extension) -> [LabeledValue] {
        guard ext.oid == oid, let policies = try? CertificatePolicies(ext) else { return [] }

        var entries: [LabeledValue] = []

        for (index, policy) in policies.policies.enumerated() {
            let prefix = "Policy #\(index + 1)"
            entries.append(LabeledValue(label: "\(prefix) Identifier", value: String(describing: policy.identifier)))

            for qualifier in policy.qualifiers {
                entries.append(LabeledValue(label: "\(prefix) \(qualifier.label)", value: qualifier.value))
            }
        }

        return entries
    }
}

private struct CertificatePolicies {
    let policies: [PolicyInformation]

    init(_ ext: X509.Certificate.Extension) throws {
        policies = try DER.sequence(
            of: PolicyInformation.self,
            identifier: .sequence,
            rootNode: DER.parse(ext.value)
        )
    }
}

private struct PolicyInformation: DERParseable {
    let identifier: ASN1ObjectIdentifier
    let qualifiers: [PolicyQualifier]

    init(derEncoded node: ASN1Node) throws {
        self = try DER.sequence(node, identifier: .sequence) { nodes in
            let policyIdentifier = try ASN1ObjectIdentifier(derEncoded: &nodes)
            let qualifiers: [PolicyQualifier]

            if let qualifierNode = nodes.next() {
                qualifiers = try DER.sequence(of: PolicyQualifier.self, identifier: .sequence, rootNode: qualifierNode)
            } else {
                qualifiers = []
            }

            return PolicyInformation(identifier: policyIdentifier, qualifiers: qualifiers)
        }
    }

    init(identifier: ASN1ObjectIdentifier, qualifiers: [PolicyQualifier]) {
        self.identifier = identifier
        self.qualifiers = qualifiers
    }
}

private struct PolicyQualifier: DERParseable {
    let label: String
    let value: String

    private static let cpsQualifierID: ASN1ObjectIdentifier = [1, 3, 6, 1, 5, 5, 7, 2, 1]
    private static let userNoticeQualifierID: ASN1ObjectIdentifier = [1, 3, 6, 1, 5, 5, 7, 2, 2]

    init(derEncoded node: ASN1Node) throws {
        self = try DER.sequence(node, identifier: .sequence) { nodes in
            let qualifierID = try ASN1ObjectIdentifier(derEncoded: &nodes)
            let qualifierValue = try ASN1Any(derEncoded: &nodes)

            if qualifierID == Self.cpsQualifierID,
               let cpsURI = try? ASN1IA5String(asn1Any: qualifierValue)
            {
                return PolicyQualifier(label: "CPS URI", value: String(decoding: cpsURI.bytes, as: UTF8.self))
            }

            if qualifierID == Self.userNoticeQualifierID,
               let userNotice = try? UserNotice(asn1Any: qualifierValue)
            {
                return PolicyQualifier(label: "User Notice", value: userNotice.value)
            }

            return PolicyQualifier(
                label: "Qualifier \(qualifierID)",
                value: String(describing: qualifierValue)
            )
        }
    }

    init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

private struct UserNotice: DERParseable {
    let value: String

    init(derEncoded node: ASN1Node) throws {
        self = try DER.sequence(node, identifier: .sequence) { nodes in
            var explicitText: String?

            if let firstNode = nodes.next() {
                if firstNode.identifier == .sequence {
                    if let secondNode = nodes.next() {
                        explicitText = decodeDisplayText(from: secondNode)
                    }
                } else {
                    explicitText = decodeDisplayText(from: firstNode)
                }
            }

            return UserNotice(value: explicitText ?? "Present")
        }
    }

    init(value: String) {
        self.value = value
    }
}

private func decodeDisplayText(from node: ASN1Node) -> String? {
    if let utf8 = try? ASN1UTF8String(derEncoded: node, withIdentifier: .utf8String) {
        return String(decoding: utf8.bytes, as: UTF8.self)
    }

    if let printable = try? ASN1PrintableString(derEncoded: node, withIdentifier: .printableString) {
        return String(decoding: printable.bytes, as: UTF8.self)
    }

    if let ia5 = try? ASN1IA5String(derEncoded: node, withIdentifier: .ia5String) {
        return String(decoding: ia5.bytes, as: UTF8.self)
    }

    if let teletex = try? ASN1TeletexString(derEncoded: node, withIdentifier: .teletexString) {
        return String(decoding: teletex.bytes, as: UTF8.self)
    }

    return nil
}
