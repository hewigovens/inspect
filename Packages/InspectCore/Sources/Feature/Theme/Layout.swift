import SwiftUI

private struct PlatformValues {
    let rootStackSpacing: CGFloat
    let rootSideRailWidth: CGFloat
    let rootCompactContentMaxWidth: CGFloat?
    let rootCompactHorizontalPadding: CGFloat
    let rootDashboardMinimumWidth: CGFloat
    let inputRegularMinimumContentWidth: CGFloat
    let inputCardSpacing: CGFloat
    let inputSampleColumnWidth: CGFloat
    let inputDemoTargetVerticalPadding: CGFloat
    let inputDemoTargetControlSize: ControlSize
    let inputPrompt: String
    let inputPromptFont: Font
    let inputUsesHorizontalCompactDemoTargets: Bool
    let inputUsesInlineCompactInputControls: Bool
    let diagnosticsContentMaxWidth: CGFloat

    static let current: PlatformValues = {
        #if os(macOS)
            PlatformValues(
                rootStackSpacing: 16,
                rootSideRailWidth: 380,
                rootCompactContentMaxWidth: 1140,
                rootCompactHorizontalPadding: 28,
                rootDashboardMinimumWidth: 700,
                inputRegularMinimumContentWidth: 760,
                inputCardSpacing: 12,
                inputSampleColumnWidth: 320,
                inputDemoTargetVerticalPadding: 6,
                inputDemoTargetControlSize: .small,
                inputPrompt: "Inspect a host name or HTTPS URL.",
                inputPromptFont: .inspectRootCaptionSemibold,
                inputUsesHorizontalCompactDemoTargets: true,
                inputUsesInlineCompactInputControls: true,
                diagnosticsContentMaxWidth: 920
            )
        #else
            PlatformValues(
                rootStackSpacing: 18,
                rootSideRailWidth: 360,
                rootCompactContentMaxWidth: nil,
                rootCompactHorizontalPadding: 20,
                rootDashboardMinimumWidth: 700,
                inputRegularMinimumContentWidth: 680,
                inputCardSpacing: 14,
                inputSampleColumnWidth: 300,
                inputDemoTargetVerticalPadding: 8,
                inputDemoTargetControlSize: .regular,
                inputPrompt: "Enter a host name or HTTPS URL.",
                inputPromptFont: .inspectRootSubheadline,
                inputUsesHorizontalCompactDemoTargets: false,
                inputUsesInlineCompactInputControls: false,
                diagnosticsContentMaxWidth: 760
            )
        #endif
    }()
}

enum InspectLayout {
    // A regular size class alone does not guarantee enough room: the Duo inner
    // display is regular width in portrait but too narrow for the side rail.
    static func fitsRegularWidth(
        _ width: CGFloat?,
        minimum: CGFloat,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Bool {
        guard horizontalSizeClass == .regular else {
            return false
        }

        guard let width else {
            return true
        }

        return width >= minimum
    }

    enum Root {
        static func usesRegularDashboardLayout(
            presentation: InspectionPresentation,
            horizontalSizeClass: UserInterfaceSizeClass?,
            availableWidth: CGFloat? = nil
        ) -> Bool {
            guard presentation == .app else {
                return false
            }

            #if os(macOS)
                return true
            #else
                return fitsRegularWidth(
                    availableWidth,
                    minimum: dashboardMinimumWidth,
                    horizontalSizeClass: horizontalSizeClass
                )
            #endif
        }

        static func contentMaxWidth(usesRegularDashboardLayout: Bool) -> CGFloat? {
            usesRegularDashboardLayout ? 1480 : PlatformValues.current.rootCompactContentMaxWidth
        }

        static func horizontalPadding(usesRegularDashboardLayout: Bool) -> CGFloat {
            usesRegularDashboardLayout ? 32 : PlatformValues.current.rootCompactHorizontalPadding
        }

        static var stackSpacing: CGFloat {
            PlatformValues.current.rootStackSpacing
        }

        static var sideRailWidth: CGFloat {
            PlatformValues.current.rootSideRailWidth
        }

        // A fixed rail starves the main column once the dashboard is allowed at
        // narrower widths, so the rail shrinks with the container.
        static func sideRailWidth(forAvailableWidth width: CGFloat?) -> CGFloat {
            let full = PlatformValues.current.rootSideRailWidth
            guard let width else {
                return full
            }

            return min(full, max(full * 0.7, width * 0.34))
        }

        static var dashboardMinimumWidth: CGFloat {
            PlatformValues.current.rootDashboardMinimumWidth
        }
    }

    enum Input {
        static func usesRegularWidthLayout(
            horizontalSizeClass: UserInterfaceSizeClass?,
            availableWidth: CGFloat? = nil
        ) -> Bool {
            #if os(macOS)
                return true
            #else
                return fitsRegularWidth(
                    availableWidth,
                    minimum: regularWidthMinimum,
                    horizontalSizeClass: horizontalSizeClass
                )
            #endif
        }

        static var regularWidthMinimum: CGFloat {
            PlatformValues.current.inputRegularMinimumContentWidth
        }

        static var usesHorizontalCompactDemoTargets: Bool {
            PlatformValues.current.inputUsesHorizontalCompactDemoTargets
        }

        static var usesInlineCompactInputControls: Bool {
            PlatformValues.current.inputUsesInlineCompactInputControls
        }

        static var inputPrompt: String {
            PlatformValues.current.inputPrompt
        }

        static var promptFont: Font {
            PlatformValues.current.inputPromptFont
        }

        static var cardSpacing: CGFloat {
            PlatformValues.current.inputCardSpacing
        }

        static var sampleColumnWidth: CGFloat {
            PlatformValues.current.inputSampleColumnWidth
        }

        static var demoTargetVerticalPadding: CGFloat {
            PlatformValues.current.inputDemoTargetVerticalPadding
        }

        static var demoTargetControlSize: ControlSize {
            PlatformValues.current.inputDemoTargetControlSize
        }
    }

    enum Monitor {
        static var usesInlineCardSearch: Bool {
            #if os(iOS) || os(macOS)
                true
            #else
                false
            #endif
        }

        static var inlineSearchButtonSize: CGFloat {
            32
        }

        static var scrollBottomContentPadding: CGFloat {
            24
        }
    }

    enum Diagnostics {
        static var contentMaxWidth: CGFloat {
            PlatformValues.current.diagnosticsContentMaxWidth
        }
    }

    enum Summary {
        static var badgeSpacing: CGFloat {
            10
        }

        static var maxBadgesPerRow: Int {
            4
        }
    }
}
