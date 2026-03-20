import Foundation
import InspectCore
import Testing

@Test
func probeHostPrefersServerNameOverRemoteHost() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "93.184.216.34",
        serverName: "example.com"
    )
    #expect(obs.probeHost == "example.com")
}

@Test
func probeHostFallsBackToRemoteHostWhenNoServerName() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "example.com"
    )
    #expect(obs.probeHost == "example.com")
}

@Test
func probeHostRejectsIPAddressServerName() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "example.com",
        serverName: "93.184.216.34"
    )
    #expect(obs.probeHost == "example.com")
}

@Test
func probeHostRejectsIPv6ServerName() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "example.com",
        serverName: "2001:db8::1"
    )
    #expect(obs.probeHost == "example.com")
}

@Test
func probeHostIsNilWhenBothAreIPAddresses() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "93.184.216.34",
        serverName: "10.0.0.1"
    )
    #expect(obs.probeHost == nil)
}

@Test
func probeHostIsNilWhenBothNil() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: nil
    )
    #expect(obs.probeHost == nil)
}

@Test
func probeHostTrimsAndLowercases() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: nil,
        serverName: "  Example.COM  "
    )
    #expect(obs.probeHost == "example.com")
}

@Test
func probeHostRejectsWhitespaceOnly() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "   ",
        serverName: "  "
    )
    #expect(obs.probeHost == nil)
}

@Test
func passiveInspectionHostAcceptsIPAddresses() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: "93.184.216.34",
        serverName: "93.184.216.34"
    )
    #expect(obs.passiveInspectionHost == "93.184.216.34")
}

@Test
func probeURLOmitsDefaultPort() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: nil,
        remotePort: 443,
        serverName: "example.com"
    )
    let url = obs.probeURL()
    #expect(url?.absoluteString == "https://example.com")
}

@Test
func probeURLIncludesNonStandardPort() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: nil,
        remotePort: 8443,
        serverName: "example.com"
    )
    let url = obs.probeURL()
    #expect(url?.absoluteString == "https://example.com:8443")
}

@Test
func probeURLIsNilWithNoHost() {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: nil
    )
    #expect(obs.probeURL() == nil)
}

@Test(arguments: [
    ("192.168.1.1", true),
    ("0.0.0.0", true),
    ("255.255.255.255", true),
    ("1.2.3", false),
    ("1.2.3.4.5", false),
    ("256.1.1.1", false),
    ("1.2.3.", false),
    (".1.2.3", false),
    ("abc.def.ghi.jkl", false),
    ("example.com", false)
])
func ipv4Validation(address: String, expected: Bool) {
    let obs = TLSFlowObservation(
        source: .networkExtension,
        remoteHost: address,
        serverName: address
    )
    if expected {
        // IP addresses are rejected by probeHost
        #expect(obs.probeHost == nil)
    } else {
        // Non-IPs are accepted by probeHost
        #expect(obs.probeHost == address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
