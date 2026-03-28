import InspectCore
import SwiftUI

struct RevocationStatusBadge: View {
    let status: RevocationStatus
    let onCheck: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)

                if let detail {
                    Text(detail)
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if status == .unchecked {
                Button("Check", action: onCheck)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(Color.inspectAccent)
                    .buttonStyle(.plain)
            }

            if status == .checking {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch status {
        case .unchecked: return "shield.slash"
        case .checking: return "shield.slash"
        case .good: return "checkmark.shield.fill"
        case .revoked: return "xmark.shield.fill"
        case .unreachable: return "exclamationmark.shield"
        }
    }

    private var tint: Color {
        switch status {
        case .unchecked, .checking: return .secondary
        case .good: return .green
        case .revoked: return .red
        case .unreachable: return .orange
        }
    }

    private var title: String {
        switch status {
        case .unchecked: return "Revocation not checked"
        case .checking: return "Checking revocation…"
        case .good: return "Not revoked"
        case .revoked: return "Certificate revoked"
        case .unreachable: return "Revocation check inconclusive"
        }
    }

    private var detail: String? {
        switch status {
        case .unchecked: return "OCSP and CRL endpoints"
        case .checking: return nil
        case .good: return "OCSP/CRL verification passed"
        case .revoked(let reason): return reason
        case .unreachable(let reason): return reason
        }
    }
}
