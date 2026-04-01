#if !os(macOS)
    import SwiftUI

    extension CertificateDetailView {
        var platformContent: some View {
            List {
                if inspection.didRedirect {
                    reportSection
                }

                chainSection

                Section {
                    RevocationStatusBadge(
                        status: revocationStatus,
                        onCheck: checkRevocation
                    )
                } header: {
                    sectionHeader("Revocation")
                }

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

        var reportSection: some View {
            Section {
                Picker("TLS Hop", selection: $selectedReportIndex) {
                    ForEach(Array(inspection.reports.enumerated()), id: \.element.id) { index, report in
                        Text("Hop \(index + 1) • \(report.host)").tag(index)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedReportIndex) { _, newValue in
                    updateReportSelection(to: newValue)
                }
            } header: {
                sectionHeader("TLS Hop")
            }
        }

        var chainSection: some View {
            Section {
                CompactCertificateChainPanel(
                    nodes: chainNodes,
                    trust: selectedReport?.trust ?? .unchecked,
                    selectedIndex: selectedIndex,
                    onSelect: updateSelection(to:)
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            } header: {
                sectionHeader(inspection.didRedirect ? "Certificate Chain For Selected Hop" : "Certificate Chain")
            }
        }

        func detailSection(_ section: CertificateDetailSection) -> some View {
            Section {
                ForEach(section.rows) { row in
                    detailRow(row)
                }
            } header: {
                sectionHeader(section.title)
            }
        }

        @ViewBuilder
        func detailRow(_ row: DetailLine) -> some View {
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

        func sectionHeader(_ title: String) -> some View {
            Text(title.uppercased())
                .font(.inspectDetailCaptionSemibold)
                .foregroundStyle(.secondary)
        }
    }

#endif
