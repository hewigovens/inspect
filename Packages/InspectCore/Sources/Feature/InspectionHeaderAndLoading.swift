import SwiftUI

struct InspectionPageHeader: View {
    let closeAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Text("Inspect")
                    .font(.inspectRootTitle)
                    .frame(maxWidth: .infinity)

                if let closeAction {
                    HStack {
                        Spacer()
                        Button(action: closeAction) {
                            Image(systemName: "xmark")
                                .font(.inspectRootHeadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color.inspectChromeMutedFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("action.close")
                    }
                }
            }

            Text("TLS Certificate Inspector")
                .font(.inspectRootSubheadlineSemibold)
                .foregroundStyle(.primary.opacity(0.88))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

struct InspectionLoadingCard: View {
    var body: some View {
        InspectCard {
            HStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Handshaking")
                        .font(.inspectRootHeadline)
                    Text("Collecting the trust chain and negotiated protocol.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}
