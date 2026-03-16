import Foundation

@MainActor
public final class InspectionReviewDebugTrigger {
    private var tapCount = 0
    private var lastTapAt = Date.distantPast
    private let requiredTapCount: Int
    private let resetInterval: TimeInterval

    public init(requiredTapCount: Int = 4, resetInterval: TimeInterval = 5) {
        self.requiredTapCount = requiredTapCount
        self.resetInterval = resetInterval
    }

    public func registerTap() -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastTapAt) > resetInterval {
            tapCount = 0
        }

        lastTapAt = now
        tapCount += 1

        guard tapCount >= requiredTapCount else {
            return false
        }

        tapCount = 0
        return true
    }
}
