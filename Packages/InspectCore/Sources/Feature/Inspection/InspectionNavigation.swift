import Foundation
import InspectCore
import SwiftUI

private struct FocusInspectionInputKey: FocusedValueKey {
    typealias Value = () -> Void
}

public extension FocusedValues {
    var focusInspectionInput: (() -> Void)? {
        get { self[FocusInspectionInputKey.self] }
        set { self[FocusInspectionInputKey.self] = newValue }
    }
}

public struct InspectionCertificateRoute: Identifiable {
    public let id = UUID()
    public let inspection: TLSInspection
    public let initialReportIndex: Int
    public let initialSelectionIndex: Int

    public init(inspection: TLSInspection, initialReportIndex: Int, initialSelectionIndex: Int) {
        self.inspection = inspection
        self.initialReportIndex = initialReportIndex
        self.initialSelectionIndex = initialSelectionIndex
    }
}

extension InspectionCertificateRoute: Hashable {
    public static func == (lhs: InspectionCertificateRoute, rhs: InspectionCertificateRoute) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#if os(macOS)
    private struct CertificateDetailSheet: View {
        @Environment(\.dismiss) private var dismiss
        let route: InspectionCertificateRoute

        var body: some View {
            NavigationStack {
                CertificateDetailView(
                    inspection: route.inspection,
                    initialReportIndex: route.initialReportIndex,
                    initialSelectionIndex: route.initialSelectionIndex
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .frame(width: 1080, height: 720)
        }
    }
#endif

public extension View {
    func certificateDetailDestination(_ route: Binding<InspectionCertificateRoute?>) -> some View {
        #if os(macOS)
            sheet(item: route) { route in
                CertificateDetailSheet(route: route)
            }
        #else
            navigationDestination(item: route) { route in
                CertificateDetailView(
                    inspection: route.inspection,
                    initialReportIndex: route.initialReportIndex,
                    initialSelectionIndex: route.initialSelectionIndex
                )
            }
        #endif
    }
}
