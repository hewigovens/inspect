import Foundation
@testable import InspectCore
import Testing

@Test
func extractsSNIFromValidClientHello() {
    let payload = buildClientHello(serverName: "example.com")
    let result = TLSClientHelloSNIExtractor.serverName(from: payload)
    #expect(result == "example.com")
}

@Test
func lowercasesSNI() {
    let payload = buildClientHello(serverName: "Example.COM")
    let result = TLSClientHelloSNIExtractor.serverName(from: payload)
    #expect(result == "example.com")
}

@Test
func returnsNilForEmptyPayload() {
    #expect(TLSClientHelloSNIExtractor.serverName(from: []) == nil)
}

@Test
func returnsNilForTruncatedPayload() {
    #expect(TLSClientHelloSNIExtractor.serverName(from: [TLSRecordContentType.handshake, 0x03, 0x01]) == nil)
}

@Test
func returnsNilForNonHandshakeRecord() {
    var payload = buildClientHello(serverName: "example.com")
    payload[0] = TLSRecordContentType.applicationData
    #expect(TLSClientHelloSNIExtractor.serverName(from: payload) == nil)
}

@Test
func returnsNilForNonTLS3xVersion() {
    var payload = buildClientHello(serverName: "example.com")
    payload[1] = 0x02
    #expect(TLSClientHelloSNIExtractor.serverName(from: payload) == nil)
}

@Test
func returnsNilForNonClientHelloHandshake() {
    var payload = buildClientHello(serverName: "example.com")
    payload[5] = TLSHandshakeType.serverHello
    #expect(TLSClientHelloSNIExtractor.serverName(from: payload) == nil)
}

@Test
func returnsNilForClientHelloWithoutSNIExtension() {
    let payload = buildClientHello(serverName: nil)
    #expect(TLSClientHelloSNIExtractor.serverName(from: payload) == nil)
}

@Test
func extractsLongSNI() {
    let longName = "very-long-subdomain.nested.deep.example.organization.com"
    let payload = buildClientHello(serverName: longName)
    let result = TLSClientHelloSNIExtractor.serverName(from: payload)
    #expect(result == longName)
}

private func buildClientHello(serverName: String?) -> [UInt8] {
    let sniNameBytes = serverName.flatMap { Array($0.utf8) } ?? []

    var sniExtension: [UInt8] = []
    if let _ = serverName {
        let nameLength = sniNameBytes.count
        let listLength = 3 + nameLength
        let extensionLength = 2 + listLength

        sniExtension += uint16(Int(TLSExtensionType.serverName))
        sniExtension += uint16(extensionLength)
        sniExtension += uint16(listLength)
        sniExtension += [TLSServerNameType.hostName]
        sniExtension += uint16(nameLength)
        sniExtension += sniNameBytes
    }

    let paddingExtension: [UInt8] = [0x00, 0x2b, 0x00, 0x03, 0x02, 0x03, 0x04]

    let extensions = paddingExtension + sniExtension
    let extensionsLength = extensions.count

    var clientHello: [UInt8] = []
    clientHello += [0x03, 0x03]
    clientHello += [UInt8](repeating: 0xAB, count: 32)
    clientHello += [0x00]
    clientHello += [0x00, 0x02, 0xC0, 0x2F]
    clientHello += [0x01, 0x00]
    clientHello += uint16(extensionsLength)
    clientHello += extensions

    let handshakeLength = clientHello.count

    var handshake: [UInt8] = []
    handshake += [TLSHandshakeType.clientHello]
    handshake += uint24(handshakeLength)
    handshake += clientHello

    let recordLength = handshake.count

    var record: [UInt8] = []
    record += [TLSRecordContentType.handshake, TLSVersion.major, 0x01]
    record += uint16(recordLength)
    record += handshake

    return record
}
