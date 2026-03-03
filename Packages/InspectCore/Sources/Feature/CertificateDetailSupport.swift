import InspectCore
import SwiftUI
import UIKit

extension Color {
    static var certificateGroupedBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    static var certificateRowBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
}

extension View {
    func inlineTitleDisplayMode() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
    }

    func ensureNavigationBarVisible() -> some View {
        self.toolbar(.visible, for: .navigationBar)
    }

    func certificateGroupedListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.certificateGroupedBackground)
    }
}

extension Font {
    static let inspectDetailSubheadline = Font.system(size: 16)
    static let inspectDetailSubheadlineSemibold = Font.system(size: 16, weight: .semibold)
    static let inspectDetailCaption = Font.system(size: 13)
    static let inspectDetailCaptionSemibold = Font.system(size: 13, weight: .semibold)
    static let inspectDetailFootnoteMonospaced = Font.system(size: 14, design: .monospaced)
}

enum CertificateExportWriter {
    static func writeTemporaryCertificate(_ certificate: CertificateDetails, host: String, indexInChain: Int) -> URL? {
        let fileName = sanitize(host: host) + "-chain-\(indexInChain + 1).cer"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try certificate.derData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func sanitize(host: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let lowered = host.lowercased().replacingOccurrences(of: ".", with: "-")
        let scalars = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let raw = String(scalars)
        return raw.replacingOccurrences(of: "--", with: "-")
    }
}

enum InspectClipboard {
    @MainActor
    static func copy(_ value: String) {
        UIPasteboard.general.string = value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct CopyFeedbackBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.inspectDetailCaptionSemibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.78), in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }
}
