import Foundation

public struct SecurityAnalyzer: Sendable {
    public init() {}

    public func analyze(requestedURL: URL, trust: TrustSummary, certificates: [CertificateDetails]) -> SecurityAssessment {
        guard let leaf = certificates.first else {
            return SecurityAssessment(findings: [
                SecurityFinding(
                    severity: .critical,
                    title: "No Certificate Chain",
                    message: "The handshake completed without a parseable certificate chain."
                ),
            ])
        }

        var findings: [SecurityFinding] = []
        findings.append(contentsOf: trustAndIdentityFindings(requestedURL: requestedURL, trust: trust, leaf: leaf))
        findings.append(contentsOf: leafProfileFindings(leaf: leaf, trust: trust))
        findings.append(contentsOf: keyAndSignatureFindings(leaf: leaf))
        findings.append(contentsOf: chainFindings(leaf: leaf, certificates: certificates))
        return SecurityAssessment(findings: findings)
    }

    private func trustAndIdentityFindings(requestedURL: URL, trust: TrustSummary, leaf: CertificateDetails) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        if trust.isTrusted {
            findings.append(SecurityFinding(
                severity: .good,
                title: "System Trust Passed",
                message: "The platform trust engine accepted the chain for this connection."
            ))
        } else {
            findings.append(SecurityFinding(
                severity: .critical,
                title: "Trust Evaluation Failed",
                message: trust.failureReason ?? "The platform trust engine rejected the chain."
            ))
        }

        if let host = requestedURL.host, host.isEmpty == false {
            if hostnameMatches(host: host, patterns: leaf.hostPatterns) {
                findings.append(SecurityFinding(
                    severity: .good,
                    title: "Hostname Covered",
                    message: "The certificate covers \(host)."
                ))
            } else {
                findings.append(SecurityFinding(
                    severity: .critical,
                    title: "Hostname Mismatch",
                    message: "The leaf certificate does not cover \(host). This is a strong interception or misconfiguration signal."
                ))
            }
        }

        switch leaf.validity.status {
        case .valid:
            break
        case .expired:
            findings.append(SecurityFinding(
                severity: .critical,
                title: "Certificate Expired",
                message: "The leaf certificate is outside its validity window."
            ))
        case .notYetValid:
            findings.append(SecurityFinding(
                severity: .critical,
                title: "Certificate Not Yet Valid",
                message: "The leaf certificate validity window starts in the future."
            ))
        }

        return findings
    }

    private func leafProfileFindings(leaf: CertificateDetails, trust: TrustSummary) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        if leaf.isSelfIssued {
            findings.append(SecurityFinding(
                severity: trust.isTrusted ? .warning : .critical,
                title: "Self-Issued Leaf",
                message: "The leaf certificate is self-issued. This is common in local PKI and interception appliances, but unusual for public websites."
            ))
        }

        if leaf.dnsNames.isEmpty, leaf.ipAddresses.isEmpty {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "No Subject Alternative Name",
                message: "The certificate falls back to Common Name matching. Modern web PKI expects SAN entries."
            ))
        }

        if isCertificateAuthority(leaf) {
            findings.append(SecurityFinding(
                severity: .critical,
                title: "Leaf Marked As Certificate Authority",
                message: "The leaf certificate is marked as a CA. That is unusual for public TLS and can indicate interception tooling or a broken PKI profile."
            ))
        }

        if leaf.keyUsage.contains(where: canSignCertificates) {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Leaf Can Sign Certificates",
                message: "The leaf key usage includes certificate-signing capabilities, which is not expected for a normal web server certificate."
            ))
        }

        return findings
    }

    private func keyAndSignatureFindings(leaf: CertificateDetails) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        if let bitSize = leaf.publicKey.bitSize, leaf.publicKey.algorithm == "RSA" {
            if bitSize < 1024 {
                findings.append(SecurityFinding(
                    severity: .critical,
                    title: "Very Weak RSA Key",
                    message: "The leaf certificate uses a \(bitSize)-bit RSA key."
                ))
            } else if bitSize < 2048 {
                findings.append(SecurityFinding(
                    severity: .warning,
                    title: "Weak RSA Key",
                    message: "The leaf certificate uses a \(bitSize)-bit RSA key."
                ))
            }
        }

        let loweredSignature = leaf.signatureAlgorithm.lowercased()
        if loweredSignature.contains("md5") || loweredSignature.contains("sha-1") || loweredSignature.contains("sha1") {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Weak Signature Algorithm",
                message: "The leaf certificate uses \(leaf.signatureAlgorithm), which is considered weak for modern TLS."
            ))
        }

        return findings
    }

    private func chainFindings(leaf: CertificateDetails, certificates: [CertificateDetails]) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        if leaf.extendedKeyUsage.isEmpty == false,
           leaf.extendedKeyUsage.contains(where: isServerAuthUsage) == false
        {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Missing Server Auth EKU",
                message: "The leaf certificate declares EKUs, but none of them are for TLS server authentication."
            ))
        }

        if leaf.authorityInfoAccess.isEmpty {
            findings.append(SecurityFinding(
                severity: .info,
                title: "No Revocation Endpoints",
                message: "No Authority Information Access extension was present on the leaf certificate."
            ))
        }

        let interceptionProducts = detectedInterceptionProducts(in: certificates)
        if !interceptionProducts.isEmpty {
            findings.append(SecurityFinding(
                severity: .warning,
                title: "Possible TLS Interception Product",
                message: "The chain contains names commonly associated with interception software: \(interceptionProducts.joined(separator: ", "))."
            ))
        }

        findings.append(contentsOf: chainLinkageFindings(certificates: certificates))

        return findings
    }

    private func chainLinkageFindings(certificates: [CertificateDetails]) -> [SecurityFinding] {
        guard certificates.count > 1 else {
            return []
        }

        var findings: [SecurityFinding] = []

        for (child, issuer) in zip(certificates, certificates.dropFirst()) {
            guard let authorityKeyID = child.authorityKeyIdentifier.first(where: { $0.label == "Key Identifier" })?.value,
                  let subjectKeyID = issuer.subjectKeyIdentifier
            else {
                continue
            }

            if normalizeHex(authorityKeyID) != normalizeHex(subjectKeyID) {
                findings.append(SecurityFinding(
                    severity: .warning,
                    title: "Issuer Key Identifier Mismatch",
                    message: "The chain linkage between \(child.subjectSummary) and \(issuer.subjectSummary) does not line up on AKI/SKI values."
                ))
            }
        }

        return findings
    }

    private func hostnameMatches(host: String, patterns: [String]) -> Bool {
        let normalizedHost = host.lowercased()

        for pattern in patterns.map({ $0.lowercased() }) {
            if pattern == normalizedHost {
                return true
            }

            guard pattern.hasPrefix("*.") else {
                continue
            }

            let suffix = String(pattern.dropFirst(1))
            guard normalizedHost.hasSuffix(suffix) else {
                continue
            }

            let hostLabels = normalizedHost.split(separator: ".")
            let suffixLabels = suffix.split(separator: ".")

            if hostLabels.count == suffixLabels.count + 1 {
                return true
            }
        }

        return false
    }

    private func isServerAuthUsage(_ usage: String) -> Bool {
        let normalized = usage.lowercased()
        return normalized.contains("serverauth") || normalized.contains("server authentication")
    }

    private func isCertificateAuthority(_ certificate: CertificateDetails) -> Bool {
        certificate.basicConstraints.contains {
            $0.label == "Certificate Authority" && $0.value.caseInsensitiveCompare("Yes") == .orderedSame
        }
    }

    private func canSignCertificates(_ usage: String) -> Bool {
        let normalized = usage.lowercased()
        return normalized.contains("keycertsign") || normalized.contains("crlsign")
    }

    private func detectedInterceptionProducts(in certificates: [CertificateDetails]) -> [String] {
        let candidates = certificates.flatMap { certificate in
            [certificate.title, certificate.subjectSummary, certificate.issuerSummary]
                + certificate.subject.map(\.value)
                + certificate.issuer.map(\.value)
        }
        let keywords = [
            ("zscaler", "Zscaler"),
            ("cisco umbrella", "Cisco Umbrella"),
            ("umbrella", "Umbrella"),
            ("blue coat", "Blue Coat"),
            ("fortinet", "Fortinet"),
            ("netskope", "Netskope"),
            ("eset ssl filter", "ESET SSL Filter"),
            ("kaspersky", "Kaspersky"),
            ("sophos", "Sophos"),
            ("bitdefender", "Bitdefender"),
            ("mitmproxy", "mitmproxy"),
            ("burp", "Burp"),
            ("charles", "Charles"),
            ("fiddler", "Fiddler"),
            ("proxyman", "Proxyman"),
        ]

        var matches = Set<String>()

        for candidate in candidates.map({ $0.lowercased() }) {
            for (token, label) in keywords where candidate.contains(token) {
                matches.insert(label)
            }
        }

        return matches.sorted()
    }

    private func normalizeHex(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ":", with: "")
    }
}
