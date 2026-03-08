import SwiftUI

public extension Color {
    static var inspectAccent: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.color(red: 0.06, green: 0.35, blue: 0.61, alpha: 1.0),
            dark: InspectPlatform.color(red: 0.42, green: 0.66, blue: 0.98, alpha: 1.0)
        )
    }

    static var inspectBackgroundStart: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.color(red: 0.93, green: 0.95, blue: 0.98, alpha: 1.0),
            dark: InspectPlatform.color(red: 0.07, green: 0.09, blue: 0.14, alpha: 1.0)
        )
    }

    static var inspectBackgroundMiddle: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.color(red: 0.82, green: 0.90, blue: 0.96, alpha: 1.0),
            dark: InspectPlatform.color(red: 0.07, green: 0.15, blue: 0.24, alpha: 1.0)
        )
    }

    static var inspectBackgroundEnd: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.color(red: 0.97, green: 0.91, blue: 0.84, alpha: 1.0),
            dark: InspectPlatform.color(red: 0.14, green: 0.11, blue: 0.17, alpha: 1.0)
        )
    }

    static var inspectGlow: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.white(0.34),
            dark: InspectPlatform.color(red: 0.36, green: 0.55, blue: 0.88, alpha: 0.14)
        )
    }

    static var inspectShapeTint: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.color(red: 0.09, green: 0.32, blue: 0.57, alpha: 0.12),
            dark: InspectPlatform.color(red: 0.28, green: 0.50, blue: 0.82, alpha: 0.18)
        )
    }

    static var inspectCardFill: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.white(0.78),
            dark: InspectPlatform.cardFillDark
        )
    }

    static var inspectCardStroke: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.white(0.78),
            dark: InspectPlatform.white(0.08)
        )
    }

    static var inspectCardShadow: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.black(0.08),
            dark: InspectPlatform.black(0.28)
        )
    }

    static var inspectChromeFill: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.white(0.82),
            dark: InspectPlatform.chromeFillDark
        )
    }

    static var inspectChromeMutedFill: Color {
        InspectPlatform.dynamicColor(
            light: InspectPlatform.white(0.72),
            dark: InspectPlatform.chromeMutedFillDark
        )
    }
}
