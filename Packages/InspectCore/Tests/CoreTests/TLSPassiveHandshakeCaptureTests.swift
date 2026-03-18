import Foundation
@testable import InspectCore
import Testing

@Test
func clientHelloCaptureExtractsSNI() {
    var capture = TLSClientHelloCapture()
    let hello = buildMinimalClientHelloRecord(serverName: "example.com")
    let result = capture.ingest(Data(hello))
    #expect(result == "example.com")
}

@Test
func clientHelloCaptureReturnsNilForEmptyData() {
    var capture = TLSClientHelloCapture()
    #expect(capture.ingest(Data()) == nil)
}

@Test
func clientHelloCaptureAccumulatesChunks() {
    var capture = TLSClientHelloCapture()
    let hello = buildMinimalClientHelloRecord(serverName: "chunked.example.com")
    let mid = hello.count / 2
    #expect(capture.ingest(Data(hello[..<mid])) == nil)
    let result = capture.ingest(Data(hello[mid...]))
    #expect(result == "chunked.example.com")
}

@Test
func serverCertificateCaptureExtractsTLS12Certificates() {
    var capture = TLSServerCertificateCapture()
    let record = buildTLS12CertificateRecord(certificateBodies: [
        [0xDE, 0xAD, 0xBE, 0xEF],
        [0xCA, 0xFE, 0xBA, 0xBE]
    ])
    let result = capture.ingest(Data(record))
    #expect(result?.count == 2)
    #expect(result?[0] == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    #expect(result?[1] == Data([0xCA, 0xFE, 0xBA, 0xBE]))
    #expect(capture.didCompleteCapture == true)
}

@Test
func serverCertificateCaptureExtractsTLS13Certificates() {
    var capture = TLSServerCertificateCapture()
    let record = buildTLS13CertificateRecord(certificateBodies: [
        [0x01, 0x02, 0x03],
        [0x04, 0x05, 0x06]
    ])
    let result = capture.ingest(Data(record))
    #expect(result?.count == 2)
    #expect(result?[0] == Data([0x01, 0x02, 0x03]))
    #expect(result?[1] == Data([0x04, 0x05, 0x06]))
}

@Test
func serverCertificateCaptureReturnsNilForEmptyData() {
    var capture = TLSServerCertificateCapture()
    #expect(capture.ingest(Data()) == nil)
}

@Test
func serverCertificateCaptureStopsOnAlertRecord() {
    var capture = TLSServerCertificateCapture()
    // Alert record (content type 0x15)
    let alert: [UInt8] = [0x15, 0x03, 0x03, 0x00, 0x02, 0x02, 0x28]
    let result = capture.ingest(Data(alert))
    #expect(result == nil)
    #expect(capture.didCompleteCapture == true)
}

@Test
func serverCertificateCaptureIgnoresCCSRecord() {
    var capture = TLSServerCertificateCapture()
    let ccs: [UInt8] = [TLSRecordContentType.changeCipherSpec, TLSVersion.major, 0x03, 0x00, 0x01, 0x01]
    #expect(capture.ingest(Data(ccs)) == nil)
    #expect(capture.didCompleteCapture == false)
}

@Test
func serverCertificateCaptureStopsOnBufferOverflow() {
    var capture = TLSServerCertificateCapture()
    let chunkSize = 32 * 1024
    for _ in 0..<5 {
        _ = capture.ingest(Data(repeating: 0x16, count: chunkSize))
    }
    #expect(capture.didCompleteCapture == true)
}

// MARK: - Test Helpers

private func buildMinimalClientHelloRecord(serverName: String) -> [UInt8] {
    let nameBytes = Array(serverName.utf8)
    let nameLength = nameBytes.count
    let listLength = 3 + nameLength
    let extensionLength = 2 + listLength

    var sniExtension: [UInt8] = []
    sniExtension += uint16(Int(TLSExtensionType.serverName))
    sniExtension += uint16(extensionLength)
    sniExtension += uint16(listLength)
    sniExtension += [TLSServerNameType.hostName]
    sniExtension += uint16(nameLength)
    sniExtension += nameBytes

    var body: [UInt8] = []
    body += [0x03, 0x03]
    body += [UInt8](repeating: 0, count: 32)
    body += [0x00]
    body += [0x00, 0x02, 0xC0, 0x2F]
    body += [0x01, 0x00]
    body += uint16(sniExtension.count)
    body += sniExtension

    var handshake: [UInt8] = [TLSHandshakeType.clientHello]
    handshake += uint24(body.count)
    handshake += body

    var record: [UInt8] = [TLSRecordContentType.handshake, TLSVersion.major, 0x01]
    record += uint16(handshake.count)
    record += handshake
    return record
}

private func buildTLS12CertificateRecord(certificateBodies: [[UInt8]]) -> [UInt8] {
    var certsPayload: [UInt8] = []
    for cert in certificateBodies {
        certsPayload += uint24(cert.count)
        certsPayload += cert
    }

    var certMessage: [UInt8] = []
    certMessage += uint24(certsPayload.count)
    certMessage += certsPayload

    var handshake: [UInt8] = [TLSHandshakeType.certificate]
    handshake += uint24(certMessage.count)
    handshake += certMessage

    var record: [UInt8] = [TLSRecordContentType.handshake, TLSVersion.major, 0x03]
    record += uint16(handshake.count)
    record += handshake
    return record
}

private func buildTLS13CertificateRecord(certificateBodies: [[UInt8]]) -> [UInt8] {
    var certsPayload: [UInt8] = []
    for cert in certificateBodies {
        certsPayload += uint24(cert.count)
        certsPayload += cert
        certsPayload += uint16(0)
    }

    var certMessage: [UInt8] = []
    certMessage += [0x00]
    certMessage += uint24(certsPayload.count)
    certMessage += certsPayload

    var handshake: [UInt8] = [TLSHandshakeType.certificate]
    handshake += uint24(certMessage.count)
    handshake += certMessage

    var record: [UInt8] = [TLSRecordContentType.handshake, TLSVersion.major, 0x03]
    record += uint16(handshake.count)
    record += handshake
    return record
}

private func uint16(_ value: Int) -> [UInt8] {
    [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}

private func uint24(_ value: Int) -> [UInt8] {
    [UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}
