import Foundation

enum TLSClientHelloSNIExtractor {
    static func serverName(from payload: [UInt8]) -> String? {
        guard payload.count >= 5 else {
            return nil
        }

        // TLS record: Handshake(0x16), version(2), length(2)
        guard payload[0] == 0x16,
              payload[1] == 0x03 else {
            return nil
        }

        let recordLength = Int(payload[3]) << 8 | Int(payload[4])
        let recordEnd = min(payload.count, 5 + recordLength)
        guard recordEnd > 9 else {
            return nil
        }

        var cursor = 5

        // Expect ClientHello as first handshake in record.
        guard payload[cursor] == 0x01 else {
            return nil
        }

        guard cursor + 4 <= recordEnd else {
            return nil
        }

        let handshakeLength =
            (Int(payload[cursor + 1]) << 16) |
            (Int(payload[cursor + 2]) << 8) |
            Int(payload[cursor + 3])
        cursor += 4

        let handshakeEnd = min(recordEnd, cursor + handshakeLength)
        guard handshakeEnd > cursor else {
            return nil
        }

        // client_version(2) + random(32)
        guard cursor + 34 <= handshakeEnd else {
            return nil
        }
        cursor += 34

        // session_id
        guard cursor + 1 <= handshakeEnd else {
            return nil
        }
        let sessionIDLength = Int(payload[cursor])
        cursor += 1 + sessionIDLength
        guard cursor <= handshakeEnd else {
            return nil
        }

        // cipher_suites
        guard cursor + 2 <= handshakeEnd else {
            return nil
        }
        let cipherSuitesLength = (Int(payload[cursor]) << 8) | Int(payload[cursor + 1])
        cursor += 2 + cipherSuitesLength
        guard cursor <= handshakeEnd else {
            return nil
        }

        // compression_methods
        guard cursor + 1 <= handshakeEnd else {
            return nil
        }
        let compressionMethodsLength = Int(payload[cursor])
        cursor += 1 + compressionMethodsLength
        guard cursor <= handshakeEnd else {
            return nil
        }

        // extensions
        guard cursor + 2 <= handshakeEnd else {
            return nil
        }
        let extensionsLength = (Int(payload[cursor]) << 8) | Int(payload[cursor + 1])
        cursor += 2
        let extensionsEnd = min(handshakeEnd, cursor + extensionsLength)
        guard extensionsEnd > cursor else {
            return nil
        }

        while cursor + 4 <= extensionsEnd {
            let extensionType = (UInt16(payload[cursor]) << 8) | UInt16(payload[cursor + 1])
            let extensionLength = (Int(payload[cursor + 2]) << 8) | Int(payload[cursor + 3])
            cursor += 4

            guard cursor + extensionLength <= extensionsEnd else {
                return nil
            }

            if extensionType == 0x0000 {
                return parseServerNameExtension(bytes: payload, offset: cursor, length: extensionLength)
            }

            cursor += extensionLength
        }

        return nil
    }

    private static func parseServerNameExtension(bytes: [UInt8], offset: Int, length: Int) -> String? {
        guard length >= 2 else {
            return nil
        }

        let end = offset + length
        var cursor = offset

        let listLength = (Int(bytes[cursor]) << 8) | Int(bytes[cursor + 1])
        cursor += 2

        let listEnd = min(end, cursor + listLength)
        guard listEnd > cursor else {
            return nil
        }

        while cursor + 3 <= listEnd {
            let nameType = bytes[cursor]
            let nameLength = (Int(bytes[cursor + 1]) << 8) | Int(bytes[cursor + 2])
            cursor += 3

            guard cursor + nameLength <= listEnd else {
                return nil
            }

            if nameType == 0 {
                let nameBytes = Array(bytes[cursor..<(cursor + nameLength)])
                guard let name = String(bytes: nameBytes, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    name.isEmpty == false else {
                    return nil
                }

                return name.lowercased()
            }

            cursor += nameLength
        }

        return nil
    }
}
