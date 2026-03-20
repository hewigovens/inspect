import Crypto
import Foundation
import Security
import SwiftASN1
import X509

extension Certificate.Extension {
    static func mockSCTList(
        logID: [UInt8] = [UInt8](repeating: 0xAA, count: 32),
        timestampMs: UInt64 = 1_710_500_000_000
    ) throws -> Certificate.Extension {
        let signature: [UInt8] = [0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x01]

        var sctData: [UInt8] = []
        sctData.append(0x00)
        sctData.append(contentsOf: logID)
        sctData.append(contentsOf: withUnsafeBytes(of: timestampMs.bigEndian) { Array($0) })
        sctData.append(contentsOf: [0x00, 0x00])
        sctData.append(0x04)
        sctData.append(0x03)
        let sigLen = UInt16(signature.count)
        sctData.append(contentsOf: withUnsafeBytes(of: sigLen.bigEndian) { Array($0) })
        sctData.append(contentsOf: signature)

        let sctLen = UInt16(sctData.count)
        var sctListPayload: [UInt8] = []
        sctListPayload.append(contentsOf: withUnsafeBytes(of: sctLen.bigEndian) { Array($0) })
        sctListPayload.append(contentsOf: sctData)

        let totalLen = UInt16(sctListPayload.count)
        var tlsEncoded: [UInt8] = []
        tlsEncoded.append(contentsOf: withUnsafeBytes(of: totalLen.bigEndian) { Array($0) })
        tlsEncoded.append(contentsOf: sctListPayload)

        var serializer = DER.Serializer()
        try serializer.serialize(ASN1OctetString(contentBytes: tlsEncoded[...]))

        return Certificate.Extension(
            oid: [1, 3, 6, 1, 4, 1, 11129, 2, 4, 2],
            critical: false,
            value: serializer.serializedBytes[...]
        )
    }

    static func mockCRLDistributionPoints(
        uris: [String] = ["http://crl.example.test/ca.crl", "http://crl2.example.test/ca.crl"]
    ) throws -> Certificate.Extension {
        let tag0 = ASN1Identifier(tagWithNumber: 0, tagClass: .contextSpecific)
        let uriTag = ASN1Identifier(tagWithNumber: 6, tagClass: .contextSpecific)

        var serializer = DER.Serializer()
        try serializer.appendConstructedNode(identifier: .sequence) { coder in
            for uri in uris {
                try coder.appendConstructedNode(identifier: .sequence) { dpCoder in
                    try dpCoder.appendConstructedNode(identifier: tag0) { dpNameCoder in
                        try dpNameCoder.appendConstructedNode(identifier: tag0) { gnCoder in
                            let uriBytes = Array(uri.utf8)
                            try gnCoder.serialize(ASN1OctetString(contentBytes: uriBytes[...]), withIdentifier: uriTag)
                        }
                    }
                }
            }
        }

        return Certificate.Extension(
            oid: [2, 5, 29, 31],
            critical: false,
            value: serializer.serializedBytes[...]
        )
    }

    static func mockCertificatePolicies(
        policyOID: ASN1ObjectIdentifier = [1, 2, 3, 4, 5, 6, 7, 8, 1],
        cpsURI: String = "https://policy.example.test/cps",
        userNotice: String = "Inspection policy notice"
    ) throws -> Certificate.Extension {
        let cpsQualifier = try PolicyQualifierFixture(
            id: [1, 3, 6, 1, 5, 5, 7, 2, 1],
            qualifier: ASN1Any(erasing: ASN1IA5String(cpsURI))
        )
        let userNoticeQualifier = try PolicyQualifierFixture(
            id: [1, 3, 6, 1, 5, 5, 7, 2, 2],
            qualifier: ASN1Any(erasing: UserNoticeFixture(explicitText: userNotice))
        )

        let policies = CertificatePoliciesFixture([
            .init(identifier: policyOID, qualifiers: [cpsQualifier, userNoticeQualifier])
        ])

        var serializer = DER.Serializer()
        try serializer.serialize(policies)

        return Certificate.Extension(
            oid: [2, 5, 29, 32],
            critical: false,
            value: serializer.serializedBytes[...]
        )
    }
}

// MARK: - DER Helpers

extension DER.Serializer {
    mutating func serialize(_ value: ASN1OctetString, withIdentifier identifier: ASN1Identifier) throws {
        let bytes = Array(value.bytes)
        appendPrimitiveNode(identifier: identifier) { content in
            content.append(contentsOf: bytes)
        }
    }
}

private struct CertificatePoliciesFixture: DERSerializable {
    let policies: [PolicyInformationFixture]

    init(_ policies: [PolicyInformationFixture]) {
        self.policies = policies
    }

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            for policy in policies {
                try coder.serialize(policy)
            }
        }
    }
}

struct PolicyInformationFixture: DERSerializable {
    let identifier: ASN1ObjectIdentifier
    let qualifiers: [PolicyQualifierFixture]

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            try coder.serialize(identifier)
            if qualifiers.isEmpty == false {
                try coder.appendConstructedNode(identifier: .sequence) { coder in
                    for qualifier in qualifiers {
                        try coder.serialize(qualifier)
                    }
                }
            }
        }
    }
}

struct PolicyQualifierFixture: DERSerializable {
    let id: ASN1ObjectIdentifier
    let qualifier: ASN1Any

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            try coder.serialize(id)
            try coder.serialize(qualifier)
        }
    }
}

private struct UserNoticeFixture: DERSerializable {
    let explicitText: ASN1UTF8String

    init(explicitText: String) {
        self.explicitText = ASN1UTF8String(explicitText)
    }

    func serialize(into coder: inout DER.Serializer) throws {
        try coder.appendConstructedNode(identifier: .sequence) { coder in
            try coder.serialize(explicitText)
        }
    }
}
