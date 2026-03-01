import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension Color {
    static var inspectAccent: Color {
        inspectDynamic(
            light: inspectColor(red: 0.06, green: 0.35, blue: 0.61, alpha: 1.0),
            dark: inspectColor(red: 0.42, green: 0.66, blue: 0.98, alpha: 1.0)
        )
    }

    static var inspectBackgroundStart: Color {
        inspectDynamic(
            light: inspectColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1.0),
            dark: inspectColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1.0)
        )
    }

    static var inspectBackgroundMiddle: Color {
        inspectDynamic(
            light: inspectColor(red: 0.82, green: 0.90, blue: 0.96, alpha: 1.0),
            dark: inspectColor(red: 0.07, green: 0.15, blue: 0.24, alpha: 1.0)
        )
    }

    static var inspectBackgroundEnd: Color {
        inspectDynamic(
            light: inspectColor(red: 0.97, green: 0.91, blue: 0.84, alpha: 1.0),
            dark: inspectColor(red: 0.14, green: 0.11, blue: 0.17, alpha: 1.0)
        )
    }

    static var inspectGlow: Color {
        inspectDynamic(
            light: inspectWhite(0.34),
            dark: inspectColor(red: 0.36, green: 0.55, blue: 0.88, alpha: 0.14)
        )
    }

    static var inspectShapeTint: Color {
        inspectDynamic(
            light: inspectColor(red: 0.09, green: 0.32, blue: 0.57, alpha: 0.12),
            dark: inspectColor(red: 0.28, green: 0.50, blue: 0.82, alpha: 0.18)
        )
    }

    static var inspectCardFill: Color {
        inspectDynamic(
            light: inspectWhite(0.78),
            dark: inspectCardFillDark
        )
    }

    static var inspectCardStroke: Color {
        inspectDynamic(
            light: inspectWhite(0.78),
            dark: inspectWhite(0.08)
        )
    }

    static var inspectCardShadow: Color {
        inspectDynamic(
            light: inspectBlack(0.08),
            dark: inspectBlack(0.28)
        )
    }

    static var inspectChromeFill: Color {
        inspectDynamic(
            light: inspectWhite(0.82),
            dark: inspectChromeFillDark
        )
    }

    static var inspectChromeMutedFill: Color {
        inspectDynamic(
            light: inspectWhite(0.72),
            dark: inspectChromeMutedFillDark
        )
    }
}

#if canImport(UIKit)
private typealias InspectPlatformColor = UIColor

private func inspectDynamic(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        }
    )
}
#elseif canImport(AppKit)
private typealias InspectPlatformColor = NSColor

private func inspectDynamic(light: NSColor, dark: NSColor) -> Color {
    Color(
        nsColor: NSColor(name: nil) { appearance in
            let best = appearance.bestMatch(from: [.darkAqua, .aqua])
            return best == .darkAqua ? dark : light
        }
    )
}
#endif

private func inspectColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> InspectPlatformColor {
    InspectPlatformColor(red: red, green: green, blue: blue, alpha: alpha)
}

private func inspectWhite(_ alpha: CGFloat) -> InspectPlatformColor {
    InspectPlatformColor.white.withAlphaComponent(alpha)
}

private func inspectBlack(_ alpha: CGFloat) -> InspectPlatformColor {
    InspectPlatformColor.black.withAlphaComponent(alpha)
}

private var inspectCardFillDark: InspectPlatformColor {
    #if canImport(UIKit)
    UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.92)
    #else
    inspectColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 0.92)
    #endif
}

private var inspectChromeFillDark: InspectPlatformColor {
    #if canImport(UIKit)
    UIColor.tertiarySystemGroupedBackground.withAlphaComponent(0.98)
    #else
    inspectColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 0.98)
    #endif
}

private var inspectChromeMutedFillDark: InspectPlatformColor {
    #if canImport(UIKit)
    UIColor.secondarySystemGroupedBackground.withAlphaComponent(0.98)
    #else
    inspectColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 0.98)
    #endif
}
