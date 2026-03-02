import Foundation

public extension Date {
    var inspectDisplayString: String {
        DateFormatter.inspectDisplayFormatter.string(from: self)
    }
}

private extension DateFormatter {
    static let inspectDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
