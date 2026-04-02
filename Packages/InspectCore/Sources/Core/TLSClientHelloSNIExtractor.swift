import Foundation

enum TLSClientHelloSNIExtractor {
    static func serverName(from payload: [UInt8]) -> String? {
        guard payload.count >= 5,
              payload[0] == TLSRecordContentType.handshake,
              payload[1] == TLSVersion.major
        else {
            return nil
        }

        let recordLength = Int(payload[3]) << 8 | Int(payload[4])
        let recordEnd = min(payload.count, 5 + recordLength)
        guard recordEnd > 9 else {
            return nil
        }

        var cursor = 5
        guard let extensionsStart = skipToExtensions(payload: payload, cursor: &cursor, recordEnd: recordEnd) else {
            return nil
        }

        return findSNIExtension(payload: payload, cursor: extensionsStart, extensionsEnd: cursor)
    }

    private static func skipToExtensions(payload: [UInt8], cursor: inout Int, recordEnd: Int) -> Int? {
        guard payload[cursor] == TLSHandshakeType.clientHello,
              cursor + 4 <= recordEnd
        else {
            return nil
        }

        let handshakeLength =
            (Int(payload[cursor + 1]) << 16) |
            (Int(payload[cursor + 2]) << 8) |
            Int(payload[cursor + 3])
        cursor += 4

        let handshakeEnd = min(recordEnd, cursor + handshakeLength)
        guard handshakeEnd > cursor,
              cursor + 34 <= handshakeEnd
        else {
            return nil
        }

        // client_version(2) + random(32)
        cursor += 34

        guard skipField(payload: payload, cursor: &cursor, end: handshakeEnd, lengthBytes: 1),
              skipField(payload: payload, cursor: &cursor, end: handshakeEnd, lengthBytes: 2),
              skipField(payload: payload, cursor: &cursor, end: handshakeEnd, lengthBytes: 1),
              cursor + 2 <= handshakeEnd
        else {
            return nil
        }

        let extensionsLength = (Int(payload[cursor]) << 8) | Int(payload[cursor + 1])
        cursor += 2
        let extensionsEnd = min(handshakeEnd, cursor + extensionsLength)
        guard extensionsEnd > cursor else { return nil }

        let extensionsStart = cursor
        cursor = extensionsEnd
        return extensionsStart
    }

    private static func skipField(payload: [UInt8], cursor: inout Int, end: Int, lengthBytes: Int) -> Bool {
        guard cursor + lengthBytes <= end else { return false }
        let length: Int
        if lengthBytes == 1 {
            length = Int(payload[cursor])
        } else {
            length = (Int(payload[cursor]) << 8) | Int(payload[cursor + 1])
        }
        cursor += lengthBytes + length
        return cursor <= end
    }

    private static func findSNIExtension(payload: [UInt8], cursor: Int, extensionsEnd: Int) -> String? {
        var cursor = cursor
        while cursor + 4 <= extensionsEnd {
            let extensionType = (UInt16(payload[cursor]) << 8) | UInt16(payload[cursor + 1])
            let extensionLength = (Int(payload[cursor + 2]) << 8) | Int(payload[cursor + 3])
            cursor += 4

            guard cursor + extensionLength <= extensionsEnd else {
                return nil
            }

            if extensionType == TLSExtensionType.serverName {
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

            if nameType == TLSServerNameType.hostName {
                let nameBytes = Array(bytes[cursor ..< (cursor + nameLength)])
                guard let name = String(bytes: nameBytes, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    name.isEmpty == false
                else {
                    return nil
                }

                return name.lowercased()
            }

            cursor += nameLength
        }

        return nil
    }
}
