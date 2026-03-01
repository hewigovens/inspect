import InspectCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct CertificateDetailView: View {
    private let report: TLSInspectionReport
    @State private var selectedIndex: Int

    public init(report: TLSInspectionReport, initialSelectionIndex: Int = 0) {
        self.report = report

        if report.certificates.indices.contains(initialSelectionIndex) {
            _selectedIndex = State(initialValue: initialSelectionIndex)
        } else {
            _selectedIndex = State(initialValue: 0)
        }
    }

    private var selectedCertificate: CertificateDetails? {
        guard report.certificates.indices.contains(selectedIndex) else {
            return nil
        }

        return report.certificates[selectedIndex]
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

            if let selectedCertificate {
                subjectSection(selectedCertificate)
                issuerSection(selectedCertificate)
                validitySection(selectedCertificate)
                certificateSection(selectedCertificate)
                usageSection(selectedCertificate)
                namesAndAccessSection(selectedCertificate)
                publicKeySection(selectedCertificate)
                fingerprintSection(selectedCertificate)
                trustMetadataSection(selectedCertificate)

                if selectedCertificate.extensions.isEmpty == false {
                    stackedSection(
                        title: "Extensions",
                        rows: selectedCertificate.extensions.map {
                            DetailLine(label: $0.label, value: $0.value, style: .stacked)
                        }
                    )
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
        .toolbar {
            if let exportURL {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: exportURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                #else
                ToolbarItem {
                    ShareLink(item: exportURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                #endif
            }
        }
    }

    @ViewBuilder
    private var chainSection: some View {
        Section {
            CompactCertificateChainPanel(
                nodes: chainNodes,
                trust: report.trust,
                selectedIndex: selectedIndex,
                onSelect: { selectedIndex = $0 }
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        } header: {
            sectionHeader("Certificate Chain")
        } footer: {
            Text("Tap a certificate to switch the detail sections below.")
        }
    }

    @ViewBuilder
    private func subjectSection(_ certificate: CertificateDetails) -> some View {
        inlineSection(title: "Subject Name", rows: certificate.subject.map(DetailLine.init))
    }

    @ViewBuilder
    private func issuerSection(_ certificate: CertificateDetails) -> some View {
        inlineSection(title: "Issuer Name", rows: certificate.issuer.map(DetailLine.init))
    }

    @ViewBuilder
    private func validitySection(_ certificate: CertificateDetails) -> some View {
        inlineSection(
            title: "Validity",
            rows: [
                DetailLine(label: "Not Valid Before", value: certificate.validity.notBefore?.inspectDisplayString ?? "Unavailable"),
                DetailLine(label: "Not Valid After", value: certificate.validity.notAfter?.inspectDisplayString ?? "Unavailable")
            ]
        )
    }

    @ViewBuilder
    private func certificateSection(_ certificate: CertificateDetails) -> some View {
        Section {
            ForEach([
                DetailLine(label: "Role", value: certificateRoleText(certificate)),
                DetailLine(label: "Version", value: certificate.version),
                DetailLine(label: "Signature Algorithm", value: certificate.signatureAlgorithm),
                DetailLine(label: "Serial Number", value: certificate.serialNumber, style: .stacked, monospaced: true),
                DetailLine(label: "Raw Signature", value: certificate.signature, style: .stacked, monospaced: true)
            ]) { row in
                detailRow(row)
            }
        } header: {
            sectionHeader("Certificate")
        }
    }

    @ViewBuilder
    private func usageSection(_ certificate: CertificateDetails) -> some View {
        let rows =
            certificate.keyUsage.map { DetailLine(label: "Key Usage", value: $0) }
            + certificate.extendedKeyUsage.map { DetailLine(label: "Extended Key Usage", value: $0) }

        if rows.isEmpty == false {
            inlineSection(title: "Usage", rows: rows)
        }
    }

    @ViewBuilder
    private func namesAndAccessSection(_ certificate: CertificateDetails) -> some View {
        let rows =
            certificate.subjectAlternativeNames.map(DetailLine.init)
            + certificate.authorityInfoAccess.map(DetailLine.init)

        if rows.isEmpty == false {
            inlineSection(title: "Names & Access", rows: rows)
        }
    }

    @ViewBuilder
    private func publicKeySection(_ certificate: CertificateDetails) -> some View {
        Section {
            ForEach([
                DetailLine(label: "Algorithm", value: certificate.publicKey.algorithm),
                DetailLine(label: "Bit Size", value: certificate.publicKey.bitSize.map(String.init) ?? "Unavailable"),
                DetailLine(label: "SPKI SHA-256", value: certificate.publicKey.spkiSHA256Fingerprint, style: .stacked, monospaced: true),
                DetailLine(label: "Key Data", value: certificate.publicKey.hexRepresentation, style: .stacked, monospaced: true)
            ]) { row in
                detailRow(row)
            }
        } header: {
            sectionHeader("Public Key")
        }
    }

    @ViewBuilder
    private func fingerprintSection(_ certificate: CertificateDetails) -> some View {
        stackedSection(
            title: "Fingerprints",
            rows: certificate.fingerprints.map {
                DetailLine(label: $0.label, value: $0.value, style: .stacked, monospaced: true)
            }
        )
    }

    @ViewBuilder
    private func trustMetadataSection(_ certificate: CertificateDetails) -> some View {
        let policyRows = certificate.policies.map {
            DetailLine(label: $0.label, value: $0.value, style: .stacked, monospaced: true)
        }

        let constraintRows = certificate.basicConstraints.map(DetailLine.init)
        let identifierRows =
            (certificate.subjectKeyIdentifier.map {
                [DetailLine(label: "Subject Key Identifier", value: $0, style: .stacked, monospaced: true)]
            } ?? [])
            + certificate.authorityKeyIdentifier.map {
                DetailLine(
                    label: $0.label,
                    value: $0.value,
                    style: .stacked,
                    monospaced: $0.label.contains("Identifier") || $0.label.contains("Serial")
                )
            }

        let rows = constraintRows + identifierRows + policyRows

        if rows.isEmpty == false {
            Section {
                ForEach(rows) { row in
                    detailRow(row)
                }
            } header: {
                sectionHeader("Trust Metadata")
            }
        }
    }

    @ViewBuilder
    private func inlineSection(title: String, rows: [DetailLine]) -> some View {
        if rows.isEmpty == false {
            Section {
                ForEach(rows) { row in
                    detailRow(row)
                }
            } header: {
                sectionHeader(title)
            }
        }
    }

    @ViewBuilder
    private func stackedSection(title: String, rows: [DetailLine]) -> some View {
        if rows.isEmpty == false {
            Section {
                ForEach(rows) { row in
                    detailRow(row)
                }
            } header: {
                sectionHeader(title)
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ row: DetailLine) -> some View {
        switch row.style {
        case .inline:
            InlineDetailRow(label: row.label, value: row.value)
        case .stacked:
            StackedDetailRow(label: row.label, value: row.value, monospaced: row.monospaced)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.inspectDetailCaptionSemibold)
            .foregroundStyle(.secondary)
    }

    private func certificateRoleText(_ certificate: CertificateDetails) -> String {
        if certificate.isLeaf {
            return "Leaf certificate"
        }
        if certificate.isRoot {
            return "Root certificate"
        }
        return "Intermediate certificate"
    }
}

private struct CertificateChainNode: Identifiable {
    let originalIndex: Int
    let depth: Int
    let certificate: CertificateDetails

    var id: String {
        certificate.id
    }
}

private enum DetailLineStyle {
    case inline
    case stacked
}

private struct DetailLine: Identifiable {
    let label: String
    let value: String
    let style: DetailLineStyle
    let monospaced: Bool

    init(label: String, value: String, style: DetailLineStyle = .inline, monospaced: Bool = false) {
        self.label = label
        self.value = value
        self.style = style
        self.monospaced = monospaced
    }

    init(_ labeledValue: LabeledValue) {
        self.init(label: labeledValue.label, value: labeledValue.value)
    }

    var id: String {
        label + "::" + value
    }
}

private struct CompactCertificateChainPanel: View {
    let nodes: [CertificateChainNode]
    let trust: TrustSummary
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { offset, node in
                Button {
                    onSelect(node.originalIndex)
                } label: {
                    CompactCertificateChainRow(
                        node: node,
                        trust: trust,
                        isSelected: selectedIndex == node.originalIndex
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    selectedIndex == node.originalIndex
                    ? Color.accentColor
                    : Color.certificateRowBackground
                )

                if offset != nodes.count - 1 {
                    Divider()
                        .padding(.leading, 58)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct CompactCertificateChainRow: View {
    let node: CertificateChainNode
    let trust: TrustSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            hierarchyGuide

            SummaryGlyph(symbol: symbol, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(node.certificate.subjectSummary)
                    .font(.inspectDetailSubheadlineSemibold)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)

                Text(node.certificate.issuerSummary)
                    .font(.inspectDetailCaption)
                    .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var hierarchyGuide: some View {
        Color.clear
            .frame(width: CGFloat(node.depth) * 26, height: 1)
    }

    private var symbol: String {
        if leafHasFailureSignal {
            return "xmark.seal.fill"
        }
        if node.certificate.isLeaf {
            return "network"
        }
        if node.certificate.isRoot {
            return "checkmark.shield.fill"
        }
        return "seal.fill"
    }

    private var tint: Color {
        if leafHasFailureSignal {
            return .red
        }
        if node.certificate.isLeaf {
            return .blue
        }
        if node.certificate.isRoot {
            return .orange
        }
        return .indigo
    }

    private var leafHasFailureSignal: Bool {
        node.certificate.isLeaf && trust.isTrusted == false
    }
}

private struct SummaryGlyph: View {
    let symbol: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.15))
                .frame(width: 30, height: 30)

            Image(systemName: symbol)
                .font(.inspectDetailCaptionSemibold)
                .foregroundStyle(tint)
        }
    }
}

private struct InlineDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.inspectDetailSubheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            Text(value)
                .font(.inspectDetailSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

private struct StackedDetailRow: View {
    let label: String
    let value: String
    let monospaced: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.inspectDetailCaptionSemibold)
                .foregroundStyle(.secondary)

            valueText
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var valueText: some View {
        if monospaced {
            Text(value)
                .font(.inspectDetailFootnoteMonospaced)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        } else {
            Text(value)
                .font(.inspectDetailSubheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension Color {
    static var certificateGroupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(red: 0.95, green: 0.95, blue: 0.97)
        #endif
    }

    static var certificateRowBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        .white
        #endif
    }
}

private extension View {
    @ViewBuilder
    func inlineTitleDisplayMode() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func ensureNavigationBarVisible() -> some View {
        #if os(iOS)
        self.toolbar(.visible, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func certificateGroupedListStyle() -> some View {
        #if os(iOS)
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.certificateGroupedBackground)
        #else
        self
            .listStyle(.automatic)
        #endif
    }
}

private extension Font {
    static let inspectDetailSubheadline = Font.system(size: 16)
    static let inspectDetailSubheadlineSemibold = Font.system(size: 16, weight: .semibold)
    static let inspectDetailCaption = Font.system(size: 13)
    static let inspectDetailCaptionSemibold = Font.system(size: 13, weight: .semibold)
    static let inspectDetailFootnoteMonospaced = Font.system(size: 14, design: .monospaced)
}

private enum CertificateExportWriter {
    static func writeTemporaryCertificate(_ certificate: CertificateDetails, host: String, indexInChain: Int) -> URL? {
        let fileName = sanitize(host: host) + "-chain-\(indexInChain + 1).cer"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try certificate.derData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func sanitize(host: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let lowered = host.lowercased().replacingOccurrences(of: ".", with: "-")
        let scalars = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let raw = String(scalars)
        return raw.replacingOccurrences(of: "--", with: "-")
    }
}
