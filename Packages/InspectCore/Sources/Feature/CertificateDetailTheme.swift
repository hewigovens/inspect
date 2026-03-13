import SwiftUI

extension Color {
    static var certificateGroupedBackground: Color {
        InspectPlatform.groupedBackground
    }

    static var certificateRowBackground: Color {
        InspectPlatform.secondaryGroupedBackground
    }

    static var certificateChainSelectionBackground: Color {
        #if os(macOS)
        return .inspectAccent.opacity(0.16)
        #else
        return .accentColor
        #endif
    }

    static func certificateChainPrimaryText(isSelected: Bool) -> Color {
        #if os(macOS)
        return .primary
        #else
        return isSelected ? .white : .primary
        #endif
    }

    static func certificateChainSecondaryText(isSelected: Bool) -> Color {
        #if os(macOS)
        return .secondary
        #else
        return isSelected ? .white.opacity(0.82) : .secondary
        #endif
    }
}

extension View {
    func certificateGroupedListStyle() -> some View {
        inspectGroupedListStyle(background: .certificateGroupedBackground)
    }
}

extension Font {
    static let inspectDetailSubheadline = Font.system(size: 16)
    static let inspectDetailSubheadlineSemibold = Font.system(size: 16, weight: .semibold)
    static let inspectDetailCaption = Font.system(size: 13)
    static let inspectDetailCaptionSemibold = Font.system(size: 13, weight: .semibold)
    static let inspectDetailFootnoteMonospaced = Font.system(size: 14, design: .monospaced)
    static let inspectDetailCompactBody = Font.system(size: 14)
    static let inspectDetailCompactBodySemibold = Font.system(size: 14, weight: .semibold)
    static let inspectDetailCompactCaption = Font.system(size: 12)
    static let inspectDetailCompactCaptionSemibold = Font.system(size: 12, weight: .semibold)
    static let inspectDetailCompactMonospaced = Font.system(size: 12, design: .monospaced)
}
