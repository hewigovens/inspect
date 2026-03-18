import Foundation
@testable import InspectCore
import Testing

// MARK: - SNI Extraction

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
    #expect(TLSClientHelloSNIExtractor.serverName(from: [0x16, 0x03, 0x01]) == nil)
}

@Test
func returnsNilForNonHandshakeRecord() {
    // Application data record (0x17) instead of handshake (0x16)
    var payload = buildClientHello(serverName: "example.com")
    payload[0] = 0x17
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
    // ServerHello (0x02) instead of ClientHello (0x01)
    var payload = buildClientHello(serverName: "example.com")
    payload[5] = 0x02
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

// MARK: - Helpers

/// Builds a minimal TLS ClientHello with optional SNI extension.
private func buildClientHello(serverName: String?) -> [UInt8] {
    let sniNameBytes = serverName.flatMap { Array($0.utf8) } ?? []

    // SNI extension payload (type 0x0000)
    var sniExtension: [UInt8] = []
    if let _ = serverName {
        // server_name_list_length (2) + name_type (1) + name_length (2) + name
        let nameLength = sniNameBytes.count
        let listLength = 3 + nameLength
        let extensionLength = 2 + listLength

        sniExtension += [0x00, 0x00] // extension type: server_name
        sniExtension += uint16(extensionLength)
        sniExtension += uint16(listLength) // server_name_list_length
        sniExtension += [0x00] // name_type: host_name
        sniExtension += uint16(nameLength)
        sniExtension += sniNameBytes
    }

    // A non-SNI extension to test skipping (supported_versions 0x002b)
    let paddingExtension: [UInt8] = [0x00, 0x2b, 0x00, 0x03, 0x02, 0x03, 0x04]

    let extensions = paddingExtension + sniExtension
    let extensionsLength = extensions.count

    // ClientHello body
    var clientHello: [UInt8] = []
    clientHello += [0x03, 0x03] // client_version: TLS 1.2
    clientHello += [UInt8](repeating: 0xAB, count: 32) // random
    clientHello += [0x00] // session_id_length: 0
    clientHello += [0x00, 0x02, 0xC0, 0x2F] // cipher_suites: 1 suite
    clientHello += [0x01, 0x00] // compression_methods: 1 (null)
    clientHello += uint16(extensionsLength)
    clientHello += extensions

    let handshakeLength = clientHello.count

    // Handshake header
    var handshake: [UInt8] = []
    handshake += [0x01] // handshake_type: ClientHello
    handshake += uint24(handshakeLength)
    handshake += clientHello

    let recordLength = handshake.count

    // TLS record header
    var record: [UInt8] = []
    record += [0x16] // content_type: Handshake
    record += [0x03, 0x01] // version: TLS 1.0
    record += uint16(recordLength)
    record += handshake

    return record
}

private func uint16(_ value: Int) -> [UInt8] {
    [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}

private func uint24(_ value: Int) -> [UInt8] {
    [UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}
