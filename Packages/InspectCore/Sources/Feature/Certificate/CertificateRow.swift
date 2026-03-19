import InspectCore
import SwiftUI

struct CertificateRow: View {
    let certificate: CertificateDetails
    let reportTrust: TrustSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(iconTint.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: iconName)
                        .foregroundStyle(iconTint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(certificate.subjectSummary)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(certificate.issuerSummary)
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.inspectRootCaptionBold)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var iconName: String {
        if certificate.isLeaf, reportTrust.isTrusted == false {
            return "xmark.shield.fill"
        }
        if certificate.isLeaf {
            return "network.badge.shield.half.filled"
        }
        if certificate.isRoot {
            return "checkmark.shield.fill"
        }
        return "shield"
    }

    private var iconTint: Color {
        if certificate.isLeaf, reportTrust.isTrusted == false {
            return .red
        }
        if certificate.isLeaf {
            return .blue
        }
        if certificate.isRoot {
            return .green
        }
        return .indigo
    }
}
