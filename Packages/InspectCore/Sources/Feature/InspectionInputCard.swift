import Observation
import SwiftUI

struct InspectionInputCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var store: InspectionStore
    @Binding var dismissDemoTarget: Bool
    let isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        InspectCard {
            Group {
                if usesRegularWidthLayout {
                    regularContent
                } else {
                    compactContent
                }
            }
        }
    }

    private var regularContent: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inspect a host or HTTPS URL")
                        .font(.inspectRootTitle3)

                    Text("Review trust, protocol, and certificate details in one workspace built for larger screens.")
                        .font(.inspectRootFootnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                inputField(verticalPadding: 12, cornerRadius: 16)

                HStack(spacing: 12) {
                    pasteButton(expands: false)
                    inspectButton(expands: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if dismissDemoTarget == false {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Try a sample")
                            .font(.inspectRootCaptionBold)
                            .foregroundStyle(.secondary)

                        Spacer()

                        dismissTargetsButton
                    }

                    knownGoodButton
                    brokenCertificateButton
                }
                .frame(width: sampleColumnWidth, alignment: .leading)
            }
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            Text(inputPrompt)
                .font(promptFont)
                .foregroundStyle(.secondary)

            if dismissDemoTarget == false {
                compactDemoTargets
            }

            compactInputControls
        }
    }

    private var compactDemoTargets: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                knownGoodButton
                brokenCertificateButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            dismissTargetsButton
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        #else
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                knownGoodButton
                brokenCertificateButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            dismissTargetsButton
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        #endif
    }

    @ViewBuilder
    private var compactInputControls: some View {
        #if os(macOS)
        HStack(alignment: .center, spacing: 10) {
            inputField(verticalPadding: 10, cornerRadius: 14)
            pasteButton(expands: false)
            inspectButton(expands: false)
        }
        #else
        inputField(verticalPadding: 14, cornerRadius: 16)

        HStack(spacing: 12) {
            pasteButton(expands: true)
            inspectButton(expands: true)
        }
        #endif
    }

    private var knownGoodButton: some View {
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
    }

    private var brokenCertificateButton: some View {
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

    private var dismissTargetsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                dismissDemoTarget = true
            }
        } label: {
            Image(systemName: "xmark")
                .font(.inspectRootCaptionBold)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.inspectChromeMutedFill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("action.dismiss-demo-target")
    }

    private func pasteButton(expands: Bool) -> some View {
        Button {
            isInputFocused.wrappedValue = false
            if let pasted = InspectPlatform.pasteboardString() {
                store.input = pasted
            }
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
                .font(.inspectRootSubheadlineSemibold)
                .frame(minWidth: expands ? nil : 116)
                .frame(maxWidth: expands ? .infinity : nil)
        }
        .buttonStyle(.bordered)
        .controlSize(usesRegularWidthLayout ? .large : .regular)
        .accessibilityIdentifier("action.paste")
    }

    private func inspectButton(expands: Bool) -> some View {
        Button {
            inspectCurrentInput()
        } label: {
            Label(store.isLoading ? "Inspecting" : "Inspect", systemImage: "shield.lefthalf.filled")
                .font(.inspectRootSubheadlineSemibold)
                .frame(minWidth: expands ? nil : 150)
                .frame(maxWidth: expands ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(usesRegularWidthLayout ? .large : .regular)
        .tint(.inspectAccent)
        .disabled(store.isLoading)
        .accessibilityIdentifier("action.inspect")
    }

    private func inputField(verticalPadding: CGFloat, cornerRadius: CGFloat) -> some View {
        TextField("hewig.dev", text: $store.input)
            .inspectURLField()
            .focused(isInputFocused)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, verticalPadding)
            .background(Color.inspectChromeFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityIdentifier("input.url")
            .onSubmit {
                inspectCurrentInput()
            }
    }

    private var inputPrompt: String {
        #if os(macOS)
        "Inspect a host name or HTTPS URL."
        #else
        "Enter a host name or HTTPS URL."
        #endif
    }

    private var promptFont: Font {
        #if os(macOS)
        .inspectRootCaptionSemibold
        #else
        .inspectRootSubheadline
        #endif
    }

    private var cardSpacing: CGFloat {
        #if os(macOS)
        12
        #else
        14
        #endif
    }

    private var usesRegularWidthLayout: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    private var sampleColumnWidth: CGFloat {
        #if os(macOS)
        320
        #else
        300
        #endif
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
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .controlSize(controlSize)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var verticalPadding: CGFloat {
        #if os(macOS)
        6
        #else
        8
        #endif
    }

    private var controlSize: ControlSize {
        #if os(macOS)
        .small
        #else
        .regular
        #endif
    }
}
