import Foundation
import InspectCore

struct CertificateChainNode: Identifiable {
    let originalIndex: Int
    let depth: Int
    let certificate: CertificateDetails

    var id: String {
        certificate.id
    }
}

enum DetailLineStyle {
    case inline
    case stacked
}

struct DetailLine: Identifiable {
    let label: String
    let value: String
    let style: DetailLineStyle
    let monospaced: Bool

    init(label: String, value: String, style: DetailLineStyle = .inline, monospaced: Bool = false) {
        self.label = label
        self.value = value
        self.style = style
        self.monospaced = monospaced
    }

    init(_ labeledValue: LabeledValue) {
        self.init(label: labeledValue.label, value: labeledValue.value)
    }

    var id: String {
        label + "::" + value
    }
}

struct CertificateDetailSection: Identifiable {
    let title: String
    let rows: [DetailLine]

    var id: String {
        title
    }
}

struct CertificateDetailContent {
    let certificate: CertificateDetails
    let sections: [CertificateDetailSection]

    init(certificate: CertificateDetails) {
        self.certificate = certificate

        var sections: [CertificateDetailSection] = []

        appendSection(
            titled: "Subject Name",
            rows: certificate.subject.map(DetailLine.init),
            into: &sections
        )
        appendSection(
            titled: "Issuer Name",
            rows: certificate.issuer.map(DetailLine.init),
            into: &sections
        )
        appendSection(
            titled: "Validity",
            rows: [
                DetailLine(label: "Not Valid Before", value: certificate.validity.notBefore?.inspectDisplayString ?? "Unavailable"),
                DetailLine(label: "Not Valid After", value: certificate.validity.notAfter?.inspectDisplayString ?? "Unavailable")
            ],
            into: &sections
        )
        appendSection(
            titled: "Certificate",
            rows: [
                DetailLine(label: "Role", value: certificateRoleText(certificate)),
                DetailLine(label: "Version", value: certificate.version),
                DetailLine(label: "Signature Algorithm", value: certificate.signatureAlgorithm),
                DetailLine(label: "Serial Number", value: certificate.serialNumber, style: .stacked, monospaced: true),
                DetailLine(label: "Raw Signature", value: certificate.signature, style: .stacked, monospaced: true)
            ],
            into: &sections
        )

        let usageRows =
            certificate.keyUsage.map { DetailLine(label: "Key Usage", value: $0) }
            + certificate.extendedKeyUsage.map { DetailLine(label: "Extended Key Usage", value: $0) }
        appendSection(titled: "Usage", rows: usageRows, into: &sections)

        let namesAndAccessRows =
            certificate.subjectAlternativeNames.map(DetailLine.init)
            + certificate.authorityInfoAccess.map(DetailLine.init)
        appendSection(titled: "Names & Access", rows: namesAndAccessRows, into: &sections)

        appendSection(
            titled: "Public Key",
            rows: [
                DetailLine(label: "Algorithm", value: certificate.publicKey.algorithm),
                DetailLine(label: "Bit Size", value: certificate.publicKey.bitSize.map(String.init) ?? "Unavailable"),
                DetailLine(label: "SPKI SHA-256", value: certificate.publicKey.spkiSHA256Fingerprint, style: .stacked, monospaced: true),
                DetailLine(label: "Key Data", value: certificate.publicKey.hexRepresentation, style: .stacked, monospaced: true)
            ],
            into: &sections
        )
        appendSection(
            titled: "Fingerprints",
            rows: certificate.fingerprints.map {
                DetailLine(label: $0.label, value: $0.value, style: .stacked, monospaced: true)
            },
            into: &sections
        )

        let policyRows = certificate.policies.map {
            DetailLine(label: $0.label, value: $0.value, style: .stacked, monospaced: true)
        }
        let constraintRows = certificate.basicConstraints.map(DetailLine.init)
        let identifierRows =
            (certificate.subjectKeyIdentifier.map {
                [DetailLine(label: "Subject Key Identifier", value: $0, style: .stacked, monospaced: true)]
            } ?? [])
            + certificate.authorityKeyIdentifier.map {
                DetailLine(
                    label: $0.label,
                    value: $0.value,
                    style: .stacked,
                    monospaced: $0.label.contains("Identifier") || $0.label.contains("Serial")
                )
            }
        appendSection(
            titled: "Trust Metadata",
            rows: constraintRows + identifierRows + policyRows,
            into: &sections
        )
        appendSection(
            titled: "Extensions",
            rows: certificate.extensions.map {
                DetailLine(
                    label: $0.label,
                    value: $0.value,
                    style: .stacked,
                    monospaced: shouldUseMonospacedDetailValue($0.value)
                )
            },
            into: &sections
        )

        self.sections = sections
    }
}

private func appendSection(
    titled title: String,
    rows: [DetailLine],
    into sections: inout [CertificateDetailSection]
) {
    guard rows.isEmpty == false else {
        return
    }

    sections.append(CertificateDetailSection(title: title, rows: rows))
}

private func certificateRoleText(_ certificate: CertificateDetails) -> String {
    if certificate.isLeaf {
        return "Leaf certificate"
    }
    if certificate.isRoot {
        return "Root certificate"
    }
    return "Intermediate certificate"
}

private func shouldUseMonospacedDetailValue(_ value: String) -> Bool {
    let collapsed = value.unicodeScalars.filter { CharacterSet.whitespacesAndNewlines.contains($0) == false }
    guard collapsed.count >= 24 else {
        return false
    }

    let hexLike = collapsed.filter { scalar in
        CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains(scalar)
    }.count

    return Double(hexLike) / Double(collapsed.count) >= 0.7
}
