import InspectCore
import Foundation
import SwiftUI

private struct FocusInspectionInputKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    public var focusInspectionInput: (() -> Void)? {
        get { self[FocusInspectionInputKey.self] }
        set { self[FocusInspectionInputKey.self] = newValue }
    }
}

public struct InspectionCertificateRoute: Identifiable {
    public let id = UUID()
    public let report: TLSInspectionReport
    public let initialSelectionIndex: Int

    public init(report: TLSInspectionReport, initialSelectionIndex: Int) {
        self.report = report
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
                report: route.report,
                initialSelectionIndex: route.initialSelectionIndex
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 960, height: 720)
    }
}
#endif

extension View {
    public func certificateDetailDestination(_ route: Binding<InspectionCertificateRoute?>) -> some View {
        #if os(macOS)
        self.sheet(item: route) { route in
            CertificateDetailSheet(route: route)
        }
        #else
        self.navigationDestination(item: route) { route in
            CertificateDetailView(
                report: route.report,
                initialSelectionIndex: route.initialSelectionIndex
            )
        }
        #endif
    }
}
