import InspectCore
import SwiftUI

public struct CertificateDetailView: View {
    private let report: TLSInspectionReport
    @State private var selectedIndex: Int
    @State private var selectedContent: CertificateDetailContent?
    @State private var copyFeedback: String?
    @State private var copyFeedbackToken = UUID()

    public init(report: TLSInspectionReport, initialSelectionIndex: Int = 0) {
        self.report = report

        let selectedIndex = report.certificates.indices.contains(initialSelectionIndex)
            ? initialSelectionIndex
            : 0
        _selectedIndex = State(initialValue: selectedIndex)
        _selectedContent = State(initialValue: Self.selectedContent(in: report, index: selectedIndex))
    }

    private var selectedCertificate: CertificateDetails? {
        selectedContent?.certificate
    }

    private var exportURL: URL? {
        guard let selectedCertificate else {
            return nil
        }

        return CertificateExportWriter.writeTemporaryCertificate(
            selectedCertificate,
            host: report.host,
            indexInChain: selectedIndex
        )
    }

    private var chainNodes: [CertificateChainNode] {
        Array(report.certificates.enumerated().reversed().enumerated()).map { depth, entry in
            CertificateChainNode(
                originalIndex: entry.offset,
                depth: depth,
                certificate: entry.element
            )
        }
    }

    public var body: some View {
        List {
            chainSection

            if let selectedContent {
                ForEach(selectedContent.sections) { section in
                    detailSection(section)
                }
            } else {
                Section {
                    Text("No certificate details were available for this inspection.")
                        .foregroundStyle(.secondary)
                } header: {
                    sectionHeader("Certificate")
                }
            }
        }
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
    }

    private var chainSection: some View {
        Section {
            CompactCertificateChainPanel(
                nodes: chainNodes,
                trust: report.trust,
                selectedIndex: selectedIndex,
                onSelect: { index in
                    selectedIndex = index
                    selectedContent = Self.selectedContent(in: report, index: index)
                }
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } header: {
            sectionHeader("Certificate Chain")
        }
    }

    private func detailSection(_ section: CertificateDetailSection) -> some View {
        Section {
            ForEach(section.rows) { row in
                detailRow(row)
            }
        } header: {
            sectionHeader(section.title)
        }
    }

    @ViewBuilder
    private func detailRow(_ row: DetailLine) -> some View {
        switch row.style {
        case .inline:
            InlineDetailRow(label: row.label, value: row.value) {
                copy(row: row)
            }
        case .stacked:
            StackedDetailRow(label: row.label, value: row.value, monospaced: row.monospaced) {
                copy(row: row)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.inspectDetailCaptionSemibold)
            .foregroundStyle(.secondary)
    }

    private static func selectedContent(in report: TLSInspectionReport, index: Int) -> CertificateDetailContent? {
        guard report.certificates.indices.contains(index) else {
            return nil
        }

        return CertificateDetailContent(certificate: report.certificates[index])
    }

    private func copy(row: DetailLine) {
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
