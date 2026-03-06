import Foundation

enum MonitorHostClassifier {
    static func normalizedDisplayHost(_ candidate: String?) -> String? {
        guard let candidate else {
            return nil
        }

        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        return trimmed.lowercased()
    }

    static func isIPAddressLiteral(_ value: String) -> Bool {
        if isIPv4Address(value) {
            return true
        }

        if value.contains(":") {
            let unwrapped = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            return unwrapped.isEmpty == false
                && unwrapped.allSatisfy { $0.isHexDigit || $0 == ":" || $0 == "." }
        }

        return false
    }

    private static func isIPv4Address(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 4 else {
            return false
        }

        for component in components {
            guard component.isEmpty == false,
                  component.count <= 3,
                  let number = Int(component),
                  (0...255).contains(number) else {
                return false
            }
        }

        return true
    }
}
