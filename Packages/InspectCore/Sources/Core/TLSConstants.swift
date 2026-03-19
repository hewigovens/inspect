import Foundation

enum TLSRecordContentType {
    static let changeCipherSpec: UInt8 = 0x14
    static let alert: UInt8 = 0x15
    static let handshake: UInt8 = 0x16
    static let applicationData: UInt8 = 0x17
}

enum TLSHandshakeType {
    static let clientHello: UInt8 = 0x01
    static let serverHello: UInt8 = 0x02
    static let certificate: UInt8 = 0x0B
}

enum TLSExtensionType {
    static let serverName: UInt16 = 0x0000
}

enum TLSServerNameType {
    static let hostName: UInt8 = 0x00
}

enum TLSVersion {
    static let major: UInt8 = 0x03
}

enum IPProtocol {
    static let tcp: UInt8 = 6
    static let udp: UInt8 = 17
}
