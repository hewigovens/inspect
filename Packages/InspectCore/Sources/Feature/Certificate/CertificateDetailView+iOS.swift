#if !os(macOS)
    import InspectCore
    import SwiftUI

    extension CertificateDetailView {
        var platformContent: some View {
            Group {
                if #available(iOS 27.1, *) {
                    arrangementContent
                } else {
                    listContent
                }
            }
        }

        /// Main/detail split that keeps the chain beside the rows it indexes.
        ///
        /// The default split style divides horizontally when the container is wider than
        /// tall and vertically when it is taller, so every Duo pose keeps both panes.
        @available(iOS 27.1, *)
        var arrangementContent: some View {
            ArrangementView {
                List { chainSection }
            } secondary: {
                List { detailPaneSections }
            }
        }

        var listContent: some View {
            List {
                chainSection
                detailPaneSections
            }
        }

        @ViewBuilder
        private var detailPaneSections: some View {
            revocationSection

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

        @ViewBuilder
        private var revocationSection: some View {
            if showsRevocationStatus {
                Section {
                    RevocationStatusBadge(
                        summary: revocationSummary
                    )
                } header: {
                    sectionHeader("Server Revocation")
                }
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
                sectionHeader("Certificate Chain")
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
