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
        content
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
        #if os(macOS)
        .onAppear {
            InspectionWindowLayoutCenter.post(.certificateDetail)
        }
        .onDisappear {
            InspectionWindowLayoutCenter.post(.standard)
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        macContent
        #else
        iOSContent
        #endif
    }

    private var iOSContent: some View {
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
    }

    #if os(macOS)
    private var macContent: some View {
        ZStack {
            Color.certificateGroupedBackground
                .ignoresSafeArea()

            InspectBackground()
                .opacity(0.22)
                .ignoresSafeArea()

            HSplitView {
                ScrollView {
                    VStack(spacing: 16) {
                        macOverviewCard

                        InspectCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Certificate Chain")
                                    .font(.inspectRootHeadline)

                                CompactCertificateChainPanel(
                                    nodes: chainNodes,
                                    trust: report.trust,
                                    selectedIndex: selectedIndex,
                                    onSelect: { index in
                                        selectedIndex = index
                                        selectedContent = Self.selectedContent(in: report, index: index)
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                }
                .frame(minWidth: 260, idealWidth: 290, maxWidth: 320)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let selectedCertificate {
                            macSelectedCertificateCard(selectedCertificate)
                        }

                        if let selectedContent {
                            ForEach(selectedContent.sections) { section in
                                MacCertificateSectionCard(section: section) { row in
                                    copy(row: row)
                                }
                            }
                        } else {
                            InspectCard {
                                Text("No certificate details were available for this inspection.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(16)
                }
                .frame(minWidth: 420, idealWidth: 520, maxWidth: .infinity)
            }
        }
    }
    #endif

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

    #if os(macOS)
    private var macOverviewCard: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    SmallFeatureGlyph(
                        symbol: selectedCertificateGlyph,
                        tint: selectedCertificateTint
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCertificate?.subjectSummary ?? report.host)
                            .font(.inspectRootTitle3)
                            .lineLimit(3)

                        Text(report.host)
                            .font(.inspectRootSubheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Badge(
                            text: report.trust.badgeText,
                            tint: report.trust.isTrusted ? .green : .orange
                        )
                        Badge(
                            text: selectedCertificate.map(certificateRoleTitle) ?? "Certificate",
                            tint: selectedCertificateTint
                        )
                    }

                    HStack(spacing: 8) {
                        Badge(text: protocolTitle, tint: .blue)
                        if let selectedCertificate {
                            Badge(
                                text: selectedCertificate.validity.status.rawValue,
                                tint: validityTint(for: selectedCertificate)
                            )
                        }
                    }
                }

                if let selectedCertificate {
                    VStack(alignment: .leading, spacing: 12) {
                        MacCertificateQuickFact(title: "Issued By", value: selectedCertificate.issuerSummary)
                        MacCertificateQuickFact(title: "Chain Position", value: "\(selectedIndex + 1) of \(report.certificates.count)")
                    }
                }

                if let failureReason = report.trust.failureReason, report.trust.isTrusted == false {
                    Text(failureReason)
                        .font(.inspectRootFootnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func macSelectedCertificateCard(_ certificate: CertificateDetails) -> some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    SmallFeatureGlyph(symbol: selectedCertificateGlyph, tint: selectedCertificateTint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(certificate.subjectSummary)
                            .font(.inspectRootHeadline)
                            .lineLimit(2)

                        Text(certificate.issuerSummary)
                            .font(.inspectRootSubheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 10) {
                    MacCertificateStatPill(title: "Role", value: certificateRoleTitle(certificate))
                    MacCertificateStatPill(title: "Version", value: certificate.version)
                    MacCertificateStatPill(title: "Algorithm", value: certificate.signatureAlgorithm)
                }
            }
        }
    }

    private var selectedCertificateGlyph: String {
        guard let selectedCertificate else {
            return "doc.text.magnifyingglass"
        }

        if selectedCertificate.isLeaf, report.trust.isTrusted == false {
            return "xmark.seal.fill"
        }
        if selectedCertificate.isLeaf {
            return "network"
        }
        if selectedCertificate.isRoot {
            return "checkmark.shield.fill"
        }
        return "seal.fill"
    }

    private var selectedCertificateTint: Color {
        guard let selectedCertificate else {
            return .inspectAccent
        }

        if selectedCertificate.isLeaf, report.trust.isTrusted == false {
            return .red
        }
        if selectedCertificate.isLeaf {
            return .blue
        }
        if selectedCertificate.isRoot {
            return .orange
        }
        return .indigo
    }

    private func validityTint(for certificate: CertificateDetails) -> Color {
        switch certificate.validity.status {
        case .valid:
            return .green
        case .expired:
            return .red
        case .notYetValid:
            return .orange
        }
    }

    private func certificateRoleTitle(_ certificate: CertificateDetails) -> String {
        if certificate.isLeaf {
            return "Leaf certificate"
        }
        if certificate.isRoot {
            return "Root certificate"
        }
        return "Intermediate certificate"
    }

    private var protocolTitle: String {
        switch report.networkProtocolName?.lowercased() {
        case "h2":
            return "HTTP/2"
        case "h3":
            return "HTTP/3"
        case "http/1.1":
            return "HTTP/1.1"
        case let value?:
            return value.uppercased()
        default:
            return "Protocol Unknown"
        }
    }
    #endif

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

#if os(macOS)
private struct MacCertificateQuickFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.inspectDetailCompactCaptionSemibold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.inspectDetailCompactBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MacCertificateStatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.inspectDetailCompactCaption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.inspectDetailCompactBodySemibold)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.inspectChromeFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MacCertificateSectionCard: View {
    let section: CertificateDetailSection
    let onCopy: (DetailLine) -> Void

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.title)
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.bottom, 6)

                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    Group {
                        switch row.style {
                        case .inline:
                            MacInlineDetailRow(row: row) {
                                onCopy(row)
                            }
                        case .stacked:
                            MacStackedDetailRow(row: row) {
                                onCopy(row)
                            }
                        }
                    }

                    if index != section.rows.count - 1 {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

private struct MacInlineDetailRow: View {
    let row: DetailLine
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(row.label)
                .font(.inspectDetailCompactCaptionSemibold)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(row.value)
                .font(.inspectDetailCompactBody)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)

            copyButton
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Copy Value", systemImage: "doc.on.doc", action: onCopy)
        }
    }

    private var copyButton: some View {
        Button(action: onCopy) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Copy \(row.label)")
    }
}

private struct MacStackedDetailRow: View {
    let row: DetailLine
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(row.label)
                    .font(.inspectDetailCompactCaptionSemibold)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.inspectDetailCompactCaptionSemibold)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.value)
                .font(row.monospaced ? .inspectDetailCompactMonospaced : .inspectDetailCompactBody)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.inspectChromeFill)
                )
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Copy Value", systemImage: "doc.on.doc", action: onCopy)
        }
    }
}
#endif
