#if os(macOS)
    import InspectCore
    import SwiftUI

    extension CertificateDetailView {
        var platformContent: some View {
            HSplitView {
                ScrollView {
                    VStack(spacing: 16) {
                        macOverviewCard

                        InspectCard {
                            VStack(alignment: .leading, spacing: 14) {
                                if inspection.didRedirect {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("TLS Hop")
                                            .font(.inspectRootHeadline)

                                        Picker("TLS Hop", selection: $selectedReportIndex) {
                                            ForEach(Array(inspection.reports.enumerated()), id: \.element.id) { index, report in
                                                Text("Hop \(index + 1) • \(report.host)").tag(index)
                                            }
                                        }
                                        .labelsHidden()
                                        .onChange(of: selectedReportIndex) { _, newValue in
                                            updateReportSelection(to: newValue)
                                        }
                                    }
                                }

                                Text("Certificate Chain")
                                    .font(.inspectRootHeadline)

                                CompactCertificateChainPanel(
                                    nodes: chainNodes,
                                    trust: selectedReport?.trust ?? .unchecked,
                                    selectedIndex: selectedIndex,
                                    onSelect: updateSelection(to:)
                                )
                            }
                        }
                    }
                    .padding(EdgeInsets(top: 52, leading: 16, bottom: 16, trailing: 16))
                }
                .frame(minWidth: 260, idealWidth: 290, maxWidth: 320)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let selectedCertificate {
                            macSelectedCertificateCard(selectedCertificate)
                        }

                        InspectCard {
                            RevocationStatusBadge(
                                status: revocationStatus,
                                onCheck: checkRevocation
                            )
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
                    .padding(EdgeInsets(top: 52, leading: 16, bottom: 16, trailing: 16))
                }
                .frame(minWidth: 420, idealWidth: 520, maxWidth: .infinity)
            }
            .background {
                ZStack {
                    Color.certificateGroupedBackground
                    InspectBackground()
                        .opacity(0.22)
                }
                .ignoresSafeArea()
            }
        }

        var macOverviewCard: some View {
            InspectCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        SmallFeatureGlyph(
                            symbol: selectedCertificateGlyph,
                            tint: selectedCertificateTint
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedCertificate?.subjectSummary ?? selectedReport?.host ?? inspection.primaryReport?.host ?? inspection.requestedURL.absoluteString)
                                .font(.inspectRootTitle3)
                                .lineLimit(3)

                            Text(selectedReport?.host ?? inspection.primaryReport?.host ?? inspection.requestedURL.absoluteString)
                                .font(.inspectRootSubheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Badge(
                                text: (selectedReport?.trust ?? .unchecked).badgeText,
                                tint: (selectedReport?.trust.isTrusted == true) ? .green : .orange
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
                            MacCertificateQuickFact(
                                title: "Chain Position",
                                value: "\(selectedIndex + 1) of \((selectedReport?.certificates.count ?? 0))"
                            )
                            if inspection.didRedirect {
                                MacCertificateQuickFact(title: "TLS Hop", value: "Hop \(selectedReportIndex + 1) of \(inspection.reports.count)")
                            }
                        }
                    }

                    if let failureReason = selectedReport?.trust.failureReason, selectedReport?.trust.isTrusted == false {
                        Text(failureReason)
                            .font(.inspectRootFootnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        func macSelectedCertificateCard(_ certificate: CertificateDetails) -> some View {
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

        var selectedCertificateGlyph: String {
            guard let selectedCertificate else {
                return "doc.text.magnifyingglass"
            }

            if selectedCertificate.isLeaf, selectedReport?.trust.isTrusted == false {
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

        var selectedCertificateTint: Color {
            guard let selectedCertificate else {
                return .inspectAccent
            }

            if selectedCertificate.isLeaf, selectedReport?.trust.isTrusted == false {
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

        func validityTint(for certificate: CertificateDetails) -> Color {
            switch certificate.validity.status {
            case .valid:
                return .green
            case .expired:
                return .red
            case .notYetValid:
                return .orange
            }
        }

        func certificateRoleTitle(_ certificate: CertificateDetails) -> String {
            if certificate.isLeaf {
                return "Leaf certificate"
            }
            if certificate.isRoot {
                return "Root certificate"
            }
            return "Intermediate certificate"
        }

        var protocolTitle: String {
            switch selectedReport?.networkProtocolName?.lowercased() {
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
    }

#endif
