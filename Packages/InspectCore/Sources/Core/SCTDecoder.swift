import Foundation
import SwiftASN1
import X509

enum SCTDecoder {
    private static let oid: ASN1ObjectIdentifier = [1, 3, 6, 1, 4, 1, 11129, 2, 4, 2]

    static func decode(from certificate: X509.Certificate) -> [LabeledValue] {
        guard let ext = certificate.extensions[oid: oid] else { return [] }
        return decode(from: ext)
    }

    static func decode(from ext: X509.Certificate.Extension) -> [LabeledValue] {
        guard ext.oid == oid,
              let outerNode = try? DER.parse(ext.value),
              let octetString = try? ASN1OctetString(derEncoded: outerNode) else {
            return []
        }
        return parseList(Array(octetString.bytes))
    }

    private static func parseList(_ bytes: [UInt8]) -> [LabeledValue] {
        var reader = ByteReader(bytes)
        guard let listLength = try? reader.readUInt16() else { return [] }

        let listEnd = min(Int(listLength) + reader.offset, bytes.count)
        var entries: [LabeledValue] = []
        var sctIndex = 1

        while reader.offset + 2 < listEnd {
            guard let sctLength = try? reader.readUInt16() else { break }
            let sctEnd = min(reader.offset + Int(sctLength), bytes.count)
            guard sctEnd - reader.offset >= 43 else { break }

            if let sct = parseSingle(&reader, end: sctEnd) {
                let prefix = "SCT #\(sctIndex)"
                entries.append(LabeledValue(label: "\(prefix) Log", value: sct.logName))
                entries.append(LabeledValue(label: "\(prefix) Timestamp", value: sct.timestamp))
                entries.append(LabeledValue(label: "\(prefix) Algorithm", value: sct.algorithm))
                entries.append(LabeledValue(label: "\(prefix) Signature", value: sct.signature))
            }

            reader.offset = sctEnd
            sctIndex += 1
        }

        return entries
    }

    private static func parseSingle(_ reader: inout ByteReader, end: Int) -> ParsedSCT? {
        guard let _ = try? reader.readUInt8() else { return nil }

        guard let logIDBytes = try? reader.readBytes(32) else { return nil }
        let logName = KnownCTLogs.name(forLogID: logIDBytes)

        guard let timestampMs = try? reader.readUInt64() else { return nil }
        let timestamp = Date(timeIntervalSince1970: Double(timestampMs) / 1000.0).inspectDisplayString

        guard let extensionsLength = try? reader.readUInt16() else { return nil }
        reader.offset += Int(extensionsLength)

        guard let hashAlgo = try? reader.readUInt8(),
              let sigAlgo = try? reader.readUInt8() else { return nil }
        let algorithm = signatureAlgorithmName(hash: hashAlgo, sig: sigAlgo)

        guard let sigLength = try? reader.readUInt16() else { return nil }
        guard let sigBytes = try? reader.readBytes(Int(sigLength)) else { return nil }
        let signature = sigBytes.inspectHexString(grouped: true)

        return ParsedSCT(logName: logName, timestamp: timestamp, algorithm: algorithm, signature: signature)
    }

    private static func signatureAlgorithmName(hash: UInt8, sig: UInt8) -> String {
        let hashName: String
        switch hash {
        case 2: hashName = "SHA-1"
        case 4: hashName = "SHA-256"
        case 5: hashName = "SHA-384"
        case 6: hashName = "SHA-512"
        default: hashName = "Hash(\(hash))"
        }

        let sigName: String
        switch sig {
        case 1: sigName = "RSA"
        case 3: sigName = "ECDSA"
        default: sigName = "Sig(\(sig))"
        }

        return "\(sigName) with \(hashName)"
    }
}

private struct ParsedSCT {
    let logName: String
    let timestamp: String
    let algorithm: String
    let signature: String
}

private struct ByteReader {
    private let data: [UInt8]
    var offset: Int = 0

    init(_ data: [UInt8]) {
        self.data = data
    }

    mutating func readUInt8() throws -> UInt8 {
        guard offset < data.count else { throw ByteReaderError.truncated }
        let value = data[offset]
        offset += 1
        return value
    }

    mutating func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else { throw ByteReaderError.truncated }
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return value
    }

    mutating func readUInt64() throws -> UInt64 {
        guard offset + 8 <= data.count else { throw ByteReaderError.truncated }
        var value: UInt64 = 0
        for i in 0..<8 {
            value = value << 8 | UInt64(data[offset + i])
        }
        offset += 8
        return value
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        guard offset + count <= data.count else { throw ByteReaderError.truncated }
        let bytes = Array(data[offset..<offset + count])
        offset += count
        return bytes
    }
}

private enum ByteReaderError: Error {
    case truncated
}
