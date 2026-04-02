import InspectCore
import SwiftUI

struct RevocationStatusBadge: View {
    let status: RevocationStatus
    let onCheck: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
                .font(.body)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)

                if let detail {
                    Text(detail)
                        .font(.inspectRootCaption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
        .animation(nil, value: status)
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
        case .unchecked: return "Status not checked"
        case .checking: return "Checking status…"
        case .good: return "Not revoked"
        case .revoked: return "Revoked"
        case .unreachable: return "Inconclusive"
        }
    }

    private var detail: String? {
        switch status {
        case .unchecked: return "OCSP / CRL endpoints"
        case .checking: return nil
        case .good: return "OCSP / CRL passed"
        case let .revoked(reason): return reason
        case let .unreachable(reason): return reason
        }
    }
}
