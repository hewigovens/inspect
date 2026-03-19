import Foundation
import InspectCore

enum MonitorHostClassifier {
    static func normalizedDisplayHost(_ candidate: String?) -> String? {
        HostNormalizer.normalized(candidate)
    }

    static func isIPAddressLiteral(_ value: String) -> Bool {
        HostNormalizer.isIPAddressLiteral(value)
    }
}
