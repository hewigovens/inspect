import Foundation

struct TLSClientHelloCapture {
    private let maximumBufferedBytes = 32 * 1024
    private var buffer = Data()

    mutating func ingest(_ data: Data) -> String? {
        guard data.isEmpty == false else {
            return nil
        }

        if buffer.count < maximumBufferedBytes {
            let remainingCapacity = maximumBufferedBytes - buffer.count
            buffer.append(data.prefix(remainingCapacity))
        }

        return TLSClientHelloSNIExtractor.serverName(from: [UInt8](buffer))
    }
}

struct TLSServerCertificateCapture {
    private let maximumBufferedBytes = 128 * 1024
    private var recordBuffer = Data()
    private var handshakeBuffer = Data()
    private(set) var didCompleteCapture = false

    mutating func ingest(_ data: Data) -> [Data]? {
        guard didCompleteCapture == false, data.isEmpty == false else {
            return nil
        }

        if recordBuffer.count < maximumBufferedBytes {
            let remainingCapacity = maximumBufferedBytes - recordBuffer.count
            recordBuffer.append(data.prefix(remainingCapacity))
        } else {
            didCompleteCapture = true
            return nil
        }

        return extractCertificatesIfAvailable()
    }

    private mutating func extractCertificatesIfAvailable() -> [Data]? {
        while recordBuffer.count >= 5 {
            let contentType = recordBuffer[0]
            let majorVersion = recordBuffer[1]
            let recordLength = (Int(recordBuffer[3]) << 8) | Int(recordBuffer[4])

            guard majorVersion == TLSVersion.major else {
                didCompleteCapture = true
                return nil
            }

            let totalRecordLength = 5 + recordLength
            guard recordBuffer.count >= totalRecordLength else {
                return nil
            }

            let payload = Data(recordBuffer[5 ..< totalRecordLength])
            recordBuffer.removeFirst(totalRecordLength)

            switch contentType {
            case TLSRecordContentType.handshake:
                handshakeBuffer.append(payload)
                if let certificates = parseHandshakeMessages() {
                    didCompleteCapture = true
                    return certificates
                }
            case TLSRecordContentType.changeCipherSpec:
                continue
            case TLSRecordContentType.alert, TLSRecordContentType.applicationData:
                didCompleteCapture = true
                return nil
            default:
                didCompleteCapture = true
                return nil
            }
        }

        return nil
    }

    private mutating func parseHandshakeMessages() -> [Data]? {
        while handshakeBuffer.count >= 4 {
            let handshakeType = handshakeBuffer[0]
            let handshakeLength =
                (Int(handshakeBuffer[1]) << 16) |
                (Int(handshakeBuffer[2]) << 8) |
                Int(handshakeBuffer[3])

            let totalHandshakeLength = 4 + handshakeLength
            guard handshakeBuffer.count >= totalHandshakeLength else {
                return nil
            }

            let body = Data(handshakeBuffer[4 ..< totalHandshakeLength])
            handshakeBuffer.removeFirst(totalHandshakeLength)

            guard handshakeType == TLSHandshakeType.certificate else {
                continue
            }

            return Self.parseTLS13CertificateMessage(body)
                ?? Self.parseTLS12CertificateMessage(body)
        }

        return nil
    }

    private static func parseTLS12CertificateMessage(_ body: Data) -> [Data]? {
        guard body.count >= 3 else {
            return nil
        }

        let totalCertificatesLength = int24(at: 0, in: body)
        guard body.count == 3 + totalCertificatesLength else {
            return nil
        }

        var cursor = 3
        var certificates: [Data] = []

        while cursor < body.count {
            guard cursor + 3 <= body.count else {
                return nil
            }

            let certificateLength = int24(at: cursor, in: body)
            cursor += 3

            guard cursor + certificateLength <= body.count else {
                return nil
            }

            certificates.append(Data(body[cursor ..< (cursor + certificateLength)]))
            cursor += certificateLength
        }

        return certificates.isEmpty ? nil : certificates
    }

    private static func parseTLS13CertificateMessage(_ body: Data) -> [Data]? {
        guard body.count >= 4 else {
            return nil
        }

        let requestContextLength = Int(body[0])
        let certificateListOffset = 1 + requestContextLength
        guard certificateListOffset + 3 <= body.count else {
            return nil
        }

        let totalCertificatesLength = int24(at: certificateListOffset, in: body)
        let certificatesStart = certificateListOffset + 3
        guard certificatesStart + totalCertificatesLength == body.count else {
            return nil
        }

        var cursor = certificatesStart
        var certificates: [Data] = []

        while cursor < body.count {
            guard cursor + 3 <= body.count else {
                return nil
            }

            let certificateLength = int24(at: cursor, in: body)
            cursor += 3

            guard cursor + certificateLength <= body.count else {
                return nil
            }

            certificates.append(Data(body[cursor ..< (cursor + certificateLength)]))
            cursor += certificateLength

            guard cursor + 2 <= body.count else {
                return nil
            }

            let extensionsLength = int16(at: cursor, in: body)
            cursor += 2

            guard cursor + extensionsLength <= body.count else {
                return nil
            }

            cursor += extensionsLength
        }

        return certificates.isEmpty ? nil : certificates
    }

    private static func int16(at offset: Int, in data: Data) -> Int {
        (Int(data[offset]) << 8) | Int(data[offset + 1])
    }

    private static func int24(at offset: Int, in data: Data) -> Int {
        (Int(data[offset]) << 16) |
            (Int(data[offset + 1]) << 8) |
            Int(data[offset + 2])
    }
}
