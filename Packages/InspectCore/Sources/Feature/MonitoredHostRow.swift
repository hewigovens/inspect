import SwiftUI

struct MonitoredHostRow: View {
    let host: InspectionMonitoredHost
    let showsChevron: Bool

    init(host: InspectionMonitoredHost, showsChevron: Bool = true) {
        self.host = host
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(host.host)
                    .font(.inspectRootSubheadlineSemibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(host.subtitle)
                    .font(.inspectRootCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(host.statusTitle)
                .font(.inspectRootCaptionSemibold)
                .foregroundStyle(statusTint)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.inspectRootCaptionBold)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("monitor.host.\(host.id)")
    }

    private var statusTint: Color {
        switch host.state {
        case .trusted:
            return .green
        case .needsReview:
            return .orange
        case .awaitingCertificate:
            return .blue
        case .hostnameUnavailable:
            return .secondary
        }
    }
}
