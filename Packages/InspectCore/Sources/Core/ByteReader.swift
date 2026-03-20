public struct ByteReader {
    private let data: [UInt8]
    public private(set) var offset: Int = 0

    public var remaining: Int { data.count - offset }

    public init(_ data: [UInt8]) {
        self.data = data
    }

    public mutating func readUInt8() throws -> UInt8 {
        guard offset < data.count else { throw ByteReaderError.truncated }
        let value = data[offset]
        offset += 1
        return value
    }

    public mutating func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else { throw ByteReaderError.truncated }
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 2
        return value
    }

    public mutating func readUInt24() throws -> Int {
        guard offset + 3 <= data.count else { throw ByteReaderError.truncated }
        let value = (Int(data[offset]) << 16) | (Int(data[offset + 1]) << 8) | Int(data[offset + 2])
        offset += 3
        return value
    }

    public mutating func readUInt64() throws -> UInt64 {
        guard offset + 8 <= data.count else { throw ByteReaderError.truncated }
        var value: UInt64 = 0
        for i in 0..<8 {
            value = value << 8 | UInt64(data[offset + i])
        }
        offset += 8
        return value
    }

    public mutating func readBytes(_ count: Int) throws -> [UInt8] {
        guard offset + count <= data.count else { throw ByteReaderError.truncated }
        let bytes = Array(data[offset..<offset + count])
        offset += count
        return bytes
    }

    public mutating func skip(_ count: Int) throws {
        guard offset + count <= data.count else { throw ByteReaderError.truncated }
        offset += count
    }
}

public enum ByteReaderError: Error {
    case truncated
}
