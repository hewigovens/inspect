import InspectCore
import Foundation

struct InspectionCertificateRoute: Identifiable {
    let id = UUID()
    let report: TLSInspectionReport
    let initialSelectionIndex: Int
}

extension InspectionCertificateRoute: Hashable {
    static func == (lhs: InspectionCertificateRoute, rhs: InspectionCertificateRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
