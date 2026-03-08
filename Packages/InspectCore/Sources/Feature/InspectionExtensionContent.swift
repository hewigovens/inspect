import SwiftUI

struct ExtensionInspectionContent: View {
    let store: InspectionStore
    let initialURL: URL?
    let closeAction: (() -> Void)?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.input.isEmpty ? (initialURL?.host ?? initialURL?.absoluteString ?? "Preparing inspection") : store.input)
                        .font(.inspectRootHeadline)

                    Text("Opening the shared page and reading the presented TLS chain.")
                        .font(.inspectRootSubheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Current Page")
            }

            if store.isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Inspecting certificate chain")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorMessage = store.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Inspection Failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.inspectRootSubheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Try Again") {
                        Task {
                            await store.inspectCurrentInput()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .extensionGroupedListStyle()
        .navigationTitle("Certificate")
        .inlineRootNavigationTitle()
        .toolbar {
            if let closeAction {
                ToolbarItem(placement: InspectPlatform.topBarLeadingPlacement) {
                    Button("Done", action: closeAction)
                }
            }
        }
    }
}
