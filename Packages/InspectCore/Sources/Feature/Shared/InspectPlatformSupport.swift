import Foundation
import SwiftUI

#if os(iOS)
import UIKit
typealias InspectPlatformColor = UIColor
typealias InspectPlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias InspectPlatformColor = NSColor
typealias InspectPlatformImage = NSImage
#endif

enum InspectPlatform {
    static func dynamicColor(light: InspectPlatformColor, dark: InspectPlatformColor) -> Color {
        #if os(iOS)
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
        #elseif os(macOS)
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil ? dark : light
            }
        )
        #endif
    }

    static func color(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> InspectPlatformColor {
        InspectPlatformColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    static func white(_ alpha: CGFloat) -> InspectPlatformColor {
        InspectPlatformColor.white.withAlphaComponent(alpha)
    }

    static func black(_ alpha: CGFloat) -> InspectPlatformColor {
        InspectPlatformColor.black.withAlphaComponent(alpha)
    }

    static var cardFillDark: InspectPlatformColor {
        #if os(iOS)
        UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.92)
        #elseif os(macOS)
        NSColor(
            red: 0.11,
            green: 0.13,
            blue: 0.18,
            alpha: 0.94
        )
        #endif
    }

    static var chromeFillDark: InspectPlatformColor {
        #if os(iOS)
        UIColor.tertiarySystemGroupedBackground.withAlphaComponent(0.98)
        #elseif os(macOS)
        NSColor(
            red: 0.16,
            green: 0.18,
            blue: 0.24,
            alpha: 0.98
        )
        #endif
    }

    static var chromeMutedFillDark: InspectPlatformColor {
        #if os(iOS)
        UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.98)
        #elseif os(macOS)
        NSColor(
            red: 0.20,
            green: 0.22,
            blue: 0.29,
            alpha: 0.96
        )
        #endif
    }

    static var groupedBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var secondaryGroupedBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    static func pasteboardString() -> String? {
        #if os(iOS)
        UIPasteboard.general.string
        #elseif os(macOS)
        NSPasteboard.general.string(forType: .string)
        #endif
    }

    @MainActor
    static func copyToPasteboard(_ value: String) {
        #if os(iOS)
        UIPasteboard.general.string = value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }

    static func image(from data: Data) -> InspectPlatformImage? {
        InspectPlatformImage(data: data)
    }

    static var topBarLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #elseif os(macOS)
        .automatic
        #endif
    }

    static var topBarTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #elseif os(macOS)
        .automatic
        #endif
    }
}

extension Image {
    init(platformImage: InspectPlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

extension View {
    func inspectPlatformURLField() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .submitLabel(.go)
        #elseif os(macOS)
        self
            .autocorrectionDisabled()
            .submitLabel(.go)
        #endif
    }

    func inspectInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        self
        #endif
    }

    func inspectNavigationBarVisible() -> some View {
        #if os(iOS)
        self.toolbar(.visible, for: .navigationBar)
        #elseif os(macOS)
        self
        #endif
    }

    func inspectNavigationBarHidden() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #elseif os(macOS)
        self
        #endif
    }

    func inspectGroupedListStyle(background: Color) -> some View {
        #if os(iOS)
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(background)
        #elseif os(macOS)
        self
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(background)
        #endif
    }

    func inspectScrollDismissesKeyboard() -> some View {
        #if os(iOS)
        self.scrollDismissesKeyboard(.immediately)
        #elseif os(macOS)
        self
        #endif
    }
}
