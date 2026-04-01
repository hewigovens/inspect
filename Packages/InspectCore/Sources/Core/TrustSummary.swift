public struct TrustSummary: Sendable, Equatable, Codable {
    public let evaluated: Bool
    public let isTrusted: Bool
    public let failureReason: String?

    public init(evaluated: Bool, isTrusted: Bool, failureReason: String?) {
        self.evaluated = evaluated
        self.isTrusted = isTrusted
        self.failureReason = failureReason
    }

    public static let unchecked = TrustSummary(
        evaluated: false,
        isTrusted: false,
        failureReason: nil
    )

    public var badgeText: String {
        if isTrusted {
            return "Trusted"
        }
        if evaluated {
            return "Failed"
        }
        return "Unchecked"
    }
}
