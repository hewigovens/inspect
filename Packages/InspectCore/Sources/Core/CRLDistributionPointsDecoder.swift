import SwiftASN1
import X509

enum CRLDistributionPointsDecoder {
    private static let oid: ASN1ObjectIdentifier = [2, 5, 29, 31]

    static func decode(from certificate: X509.Certificate) -> [LabeledValue] {
        guard let ext = certificate.extensions[oid: oid] else { return [] }
        return decode(from: ext)
    }

    static func decode(from ext: X509.Certificate.Extension) -> [LabeledValue] {
        guard ext.oid == oid,
              let parsed = try? CRLDistributionPoints(ext) else {
            return []
        }

        return parsed.uris.enumerated().map { index, uri in
            LabeledValue(label: "Distribution Point #\(index + 1)", value: uri)
        }
    }
}

private struct CRLDistributionPoints {
    let uris: [String]

    init(_ ext: X509.Certificate.Extension) throws {
        let rootNode = try DER.parse(ext.value)
        var collected: [String] = []

        try DER.sequence(rootNode, identifier: .sequence) { dpIterator in
            while let dpNode = dpIterator.next() {
                let dpURIs = (try? Self.parseDistributionPoint(dpNode)) ?? []
                collected.append(contentsOf: dpURIs)
            }
        }

        self.uris = collected
    }

    private static func parseDistributionPoint(_ node: ASN1Node) throws -> [String] {
        try DER.sequence(node, identifier: .sequence) { fields in
            var uris: [String] = []

            while let field = fields.next() {
                guard field.identifier.tagClass == .contextSpecific,
                      field.identifier.tagNumber == 0 else { continue }

                try DER.sequence(field, identifier: field.identifier) { dpNameNodes in
                    while let dpNameNode = dpNameNodes.next() {
                        guard dpNameNode.identifier.tagClass == .contextSpecific,
                              dpNameNode.identifier.tagNumber == 0 else { continue }

                        try DER.sequence(dpNameNode, identifier: dpNameNode.identifier) { gnNodes in
                            while let gnNode = gnNodes.next() {
                                guard gnNode.identifier.tagClass == .contextSpecific,
                                      gnNode.identifier.tagNumber == 6 else { continue }

                                let raw = try ASN1OctetString(derEncoded: gnNode, withIdentifier: gnNode.identifier)
                                uris.append(String(decoding: raw.bytes, as: UTF8.self))
                            }
                        }
                    }
                }
            }

            return uris
        }
    }
}
