import Observation
import SwiftUI
import UIKit

struct InspectionInputCard: View {
    @Bindable var store: InspectionStore
    @Binding var dismissDemoTarget: Bool
    let isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        InspectCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Enter a host name or HTTPS URL.")
                    .font(.inspectRootSubheadline)
                    .foregroundStyle(.secondary)

                if dismissDemoTarget == false {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 10) {
                            DemoTargetButton(
                                title: "Known Good Certificate",
                                host: "hewig.dev",
                                systemImage: "sparkles",
                                tint: .inspectAccent,
                                accessibilityIdentifier: "action.fill-example"
                            ) {
                                isInputFocused.wrappedValue = false
                                store.input = "https://hewig.dev"
                            }

                            DemoTargetButton(
                                title: "Broken Certificate",
                                host: "badssl.com",
                                systemImage: "exclamationmark.triangle.fill",
                                tint: .orange,
                                accessibilityIdentifier: "action.fill-example-bad-cert"
                            ) {
                                isInputFocused.wrappedValue = false
                                store.input = "https://untrusted-root.badssl.com"
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismissDemoTarget = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.inspectRootCaptionBold)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color.inspectChromeMutedFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.dismiss-demo-target")
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                TextField("hewig.dev", text: $store.input)
                    .inspectURLField()
                    .focused(isInputFocused)
                    .lineLimit(1)
                    .padding(14)
                    .background(Color.inspectChromeFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("input.url")
                    .onSubmit {
                        inspectCurrentInput()
                    }

                HStack(spacing: 12) {
                    Button {
                        isInputFocused.wrappedValue = false
                        if let pasted = UIPasteboard.general.string {
                            store.input = pasted
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(.inspectRootSubheadlineSemibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("action.paste")

                    Button {
                        inspectCurrentInput()
                    } label: {
                        Label(store.isLoading ? "Inspecting" : "Inspect", systemImage: "shield.lefthalf.filled")
                            .font(.inspectRootSubheadlineSemibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.inspectAccent)
                    .disabled(store.isLoading)
                    .accessibilityIdentifier("action.inspect")
                }
            }
        }
    }

    private func inspectCurrentInput() {
        isInputFocused.wrappedValue = false
        Task {
            await store.inspectCurrentInput()
        }
    }
}

private struct DemoTargetButton: View {
    let title: String
    let host: String
    let systemImage: String
    let tint: Color
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.inspectRootHeadline)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.inspectRootCaptionBold)
                    Text(host)
                        .font(.inspectRootSubheadlineSemibold)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .controlSize(.regular)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
