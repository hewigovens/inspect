import Foundation
import InspectCore
import Testing

@Test
func normalizesHostWithPath() throws {
    let normalized = try URLInputNormalizer.normalize(input: "example.com/path")
    #expect(normalized.absoluteString == "https://example.com/path")
}

@Test
func normalizesHTTPSURLPassthrough() throws {
    let normalized = try URLInputNormalizer.normalize(input: "https://example.com/page")
    #expect(normalized.absoluteString == "https://example.com/page")
}

@Test
func rejectsEmptyInput() {
    #expect(throws: InspectionError.self) {
        try URLInputNormalizer.normalize(input: "")
    }
}

@Test
func rejectsWhitespaceOnlyInput() {
    #expect(throws: InspectionError.self) {
        try URLInputNormalizer.normalize(input: "   ")
    }
}

@Test
func rejectsHTTPScheme() {
    #expect(throws: InspectionError.self) {
        try URLInputNormalizer.normalize(input: "http://example.com")
    }
}

@Test
func rejectsFTPScheme() {
    #expect(throws: InspectionError.self) {
        try URLInputNormalizer.normalize(input: "ftp://example.com")
    }
}

@Test
func trimsWhitespace() throws {
    let normalized = try URLInputNormalizer.normalize(input: "  example.com  ")
    #expect(normalized.absoluteString == "https://example.com/")
}

@Test
func normalizesURLWithPort() throws {
    let normalized = try URLInputNormalizer.normalize(input: "example.com:8443")
    #expect(normalized.host == "example.com")
    #expect(normalized.port == 8443)
}

@Test
func normalizesURLObject() throws {
    let url = URL(string: "https://example.com")!
    let normalized = try URLInputNormalizer.normalize(url: url)
    #expect(normalized.absoluteString == "https://example.com/")
}
