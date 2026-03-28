import InspectCore
import SwiftUI

public struct CertificateDetailView: View {
    @Environment(\.openURL) private var openURL
    let report: TLSInspectionReport
    @State var selectedIndex: Int
    @State var selectedContent: CertificateDetailContent?
    @State var copyFeedback: String?
    @State var copyFeedbackToken = UUID()
    @State var presentsSSLLabs = false
    @State var revocationStatus: RevocationStatus = .unchecked

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

                        if report.certificates.count > 1 {
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

                        if let sslLabsURL = report.sslLabsURL {
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
            .inspectSafariSheet(url: report.sslLabsURL, isPresented: $presentsSSLLabs)
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
        let pem = CertificateExportWriter.fullChainPEM(from: report.certificates)
        InspectClipboard.copy(pem)
        showCopyFeedback("Copied \(report.certificates.count) certificates")
    }

    func checkRevocation() {
        revocationStatus = .checking
        Task {
            let result = await RevocationChecker.check(
                certificates: report.certificates,
                host: report.host
            )
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    revocationStatus = result
                }
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
