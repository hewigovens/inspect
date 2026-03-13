import InspectCore
import SwiftUI

public struct CertificateDetailView: View {
    let report: TLSInspectionReport
    @State var selectedIndex: Int
    @State var selectedContent: CertificateDetailContent?
    @State var copyFeedback: String?
    @State var copyFeedbackToken = UUID()

    public init(report: TLSInspectionReport, initialSelectionIndex: Int = 0) {
        self.report = report

        let selectedIndex = report.certificates.indices.contains(initialSelectionIndex)
            ? initialSelectionIndex
            : 0
        _selectedIndex = State(initialValue: selectedIndex)
        _selectedContent = State(initialValue: Self.selectedContent(in: report, index: selectedIndex))
    }

    var selectedCertificate: CertificateDetails? {
        selectedContent?.certificate
    }

    var exportURL: URL? {
        guard let selectedCertificate else {
            return nil
        }

        return CertificateExportWriter.writeTemporaryCertificate(
            selectedCertificate,
            host: report.host,
            indexInChain: selectedIndex
        )
    }

    var chainNodes: [CertificateChainNode] {
        Array(report.certificates.enumerated().reversed().enumerated()).map { depth, entry in
            CertificateChainNode(
                originalIndex: entry.offset,
                depth: depth,
                certificate: entry.element
            )
        }
    }

    public var body: some View {
        platformContent
            .certificateGroupedListStyle()
            .navigationTitle("Certificate")
            .inlineTitleDisplayMode()
            .ensureNavigationBarVisible()
            .overlay(alignment: .bottom) {
                if let copyFeedback {
                    CopyFeedbackBadge(text: copyFeedback)
                        .padding(.bottom, 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar {
                if let exportURL {
                    ToolbarItem(placement: InspectPlatform.topBarTrailingPlacement) {
                        ShareLink(item: exportURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .certificateDetailWindowLifecycle()
    }

    static func selectedContent(in report: TLSInspectionReport, index: Int) -> CertificateDetailContent? {
        guard report.certificates.indices.contains(index) else {
            return nil
        }

        return CertificateDetailContent(certificate: report.certificates[index])
    }

    func updateSelection(to index: Int) {
        selectedIndex = index
        selectedContent = Self.selectedContent(in: report, index: index)
    }

    func copy(row: DetailLine) {
        InspectClipboard.copy(row.value)

        let token = UUID()
        copyFeedbackToken = token

        withAnimation(.easeInOut(duration: 0.18)) {
            copyFeedback = "Copied \(row.label)"
        }

        Task {
            try? await Task.sleep(for: .seconds(1.2))

            guard token == copyFeedbackToken else {
                return
            }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    copyFeedback = nil
                }
            }
        }
    }
}
