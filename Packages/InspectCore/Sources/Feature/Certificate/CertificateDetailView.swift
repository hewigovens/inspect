import InspectCore
import SwiftUI

public struct CertificateDetailView: View {
    @Environment(\.openURL) private var openURL
    let inspection: TLSInspection
    @State var selectedReportIndex: Int
    @State var selectedIndex: Int
    @State var selectedContent: CertificateDetailContent?
    @State var copyFeedback: String?
    @State var copyFeedbackToken = UUID()
    @State var presentsSSLLabs = false
    @State private var revocationCache: [String: RevocationStatus] = [:]

    public init(inspection: TLSInspection, initialReportIndex: Int = 0, initialSelectionIndex: Int = 0) {
        self.inspection = inspection

        let selectedReportIndex = inspection.reports.indices.contains(initialReportIndex)
            ? initialReportIndex
            : 0
        let selectedIndex = inspection.reports[safe: selectedReportIndex]?.certificates.indices.contains(initialSelectionIndex) == true
            ? initialSelectionIndex
            : 0
        _selectedReportIndex = State(initialValue: selectedReportIndex)
        _selectedIndex = State(initialValue: selectedIndex)
        _selectedContent = State(
            initialValue: Self.selectedContent(
                in: inspection.reports[safe: selectedReportIndex],
                index: selectedIndex
            )
        )
    }

    public init(report: TLSInspectionReport, initialSelectionIndex: Int = 0) {
        self.init(
            inspection: TLSInspection(report: report),
            initialReportIndex: 0,
            initialSelectionIndex: initialSelectionIndex
        )
    }

    var revocationStatus: RevocationStatus {
        guard let key = revocationCacheKey else { return .unchecked }
        return revocationCache[key] ?? .unchecked
    }

    private var revocationCacheKey: String? {
        guard let cert = selectedCertificate else { return nil }
        return "\(selectedReportIndex)-\(cert.id)"
    }

    var selectedReport: TLSInspectionReport? {
        inspection.reports[safe: selectedReportIndex]
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
            host: selectedReport?.host ?? inspection.primaryReport?.host ?? inspection.requestedURL.absoluteString,
            indexInChain: selectedIndex
        )
    }

    var chainNodes: [CertificateChainNode] {
        Array((selectedReport?.certificates ?? []).enumerated().reversed().enumerated()).map { depth, entry in
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
                ToolbarItem(placement: InspectPlatform.topBarTrailingPlacement) {
                    Menu {
                        if let exportURL {
                            ShareLink(item: exportURL) {
                                Label("Share Certificate (DER)", systemImage: "square.and.arrow.up")
                            }
                        }

                        Button {
                            copySelectedPEM()
                        } label: {
                            Label("Copy as PEM", systemImage: "doc.on.doc")
                        }

                        if let selectedReport, selectedReport.certificates.count > 1 {
                            Button {
                                copyFullChainPEM()
                            } label: {
                                Label("Copy Full Chain", systemImage: "doc.on.doc.fill")
                            }
                        }

                        Divider()

                        Button {
                            checkRevocation()
                        } label: {
                            Label("Check Revocation", systemImage: "checkmark.shield")
                        }
                        .disabled(revocationStatus == .checking)

                        if let sslLabsURL = selectedReport?.sslLabsURL {
                            Button {
                                openSSLLabs(sslLabsURL)
                            } label: {
                                Label("Open in SSL Labs", systemImage: "safari")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .inspectSafariSheet(url: selectedReport?.sslLabsURL, isPresented: $presentsSSLLabs)
    }

    static func selectedContent(in report: TLSInspectionReport?, index: Int) -> CertificateDetailContent? {
        guard let report, report.certificates.indices.contains(index) else {
            return nil
        }

        return CertificateDetailContent(certificate: report.certificates[index])
    }

    func updateSelection(to index: Int) {
        selectedIndex = index
        selectedContent = Self.selectedContent(in: selectedReport, index: index)
    }

    func updateReportSelection(to index: Int) {
        selectedReportIndex = index
        let nextCertificateIndex = inspection.reports[safe: index]?.certificates.indices.contains(selectedIndex) == true
            ? selectedIndex
            : 0
        selectedIndex = nextCertificateIndex
        selectedContent = Self.selectedContent(
            in: inspection.reports[safe: index],
            index: nextCertificateIndex
        )
    }

    func copy(row: DetailLine) {
        InspectClipboard.copy(row.value)
        showCopyFeedback("Copied \(row.label)")
    }

    func showCopyFeedback(_ message: String) {
        let token = UUID()
        copyFeedbackToken = token

        withAnimation(.easeInOut(duration: 0.18)) {
            copyFeedback = message
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

    func copySelectedPEM() {
        guard let selectedCertificate else { return }
        let pem = CertificateExportWriter.pemString(for: selectedCertificate)
        InspectClipboard.copy(pem)
        showCopyFeedback("Copied PEM")
    }

    func copyFullChainPEM() {
        let certificates = selectedReport?.certificates ?? []
        let pem = CertificateExportWriter.fullChainPEM(from: certificates)
        InspectClipboard.copy(pem)
        showCopyFeedback("Copied \(certificates.count) certificates")
    }

    func checkRevocation() {
        guard let selectedReport, let key = revocationCacheKey else {
            return
        }

        let certificatesForCheck = Array(selectedReport.certificates.dropFirst(selectedIndex))

        revocationCache[key] = .checking
        Task {
            let result = await RevocationChecker.check(
                certificates: certificatesForCheck,
                host: selectedReport.host
            )
            await MainActor.run {
                revocationCache[key] = result
            }
        }
    }

    func openSSLLabs(_ url: URL) {
        #if os(macOS)
            openURL(url)
        #else
            presentsSSLLabs = true
        #endif
    }
}
