import SwiftUI

private struct PlatformValues {
    let rootStackSpacing: CGFloat
    let rootSideRailWidth: CGFloat
    let rootCompactContentMaxWidth: CGFloat?
    let rootCompactHorizontalPadding: CGFloat
    let inputCardSpacing: CGFloat
    let inputSampleColumnWidth: CGFloat
    let inputDemoTargetVerticalPadding: CGFloat
    let inputDemoTargetControlSize: ControlSize
    let inputPrompt: String
    let inputPromptFont: Font
    let inputUsesHorizontalCompactDemoTargets: Bool
    let inputUsesInlineCompactInputControls: Bool
    let chainUsesAnimatedDetailNavigation: Bool
    let diagnosticsContentMaxWidth: CGFloat

    static let current: PlatformValues = {
        #if os(macOS)
        PlatformValues(
            rootStackSpacing: 16,
            rootSideRailWidth: 380,
            rootCompactContentMaxWidth: 1140,
            rootCompactHorizontalPadding: 28,
            inputCardSpacing: 12,
            inputSampleColumnWidth: 320,
            inputDemoTargetVerticalPadding: 6,
            inputDemoTargetControlSize: .small,
            inputPrompt: "Inspect a host name or HTTPS URL.",
            inputPromptFont: .inspectRootCaptionSemibold,
            inputUsesHorizontalCompactDemoTargets: true,
            inputUsesInlineCompactInputControls: true,
            chainUsesAnimatedDetailNavigation: true,
            diagnosticsContentMaxWidth: 920
        )
        #else
        PlatformValues(
            rootStackSpacing: 18,
            rootSideRailWidth: 360,
            rootCompactContentMaxWidth: nil,
            rootCompactHorizontalPadding: 20,
            inputCardSpacing: 14,
            inputSampleColumnWidth: 300,
            inputDemoTargetVerticalPadding: 8,
            inputDemoTargetControlSize: .regular,
            inputPrompt: "Enter a host name or HTTPS URL.",
            inputPromptFont: .inspectRootSubheadline,
            inputUsesHorizontalCompactDemoTargets: false,
            inputUsesInlineCompactInputControls: false,
            chainUsesAnimatedDetailNavigation: false,
            diagnosticsContentMaxWidth: 760
        )
        #endif
    }()
}

enum InspectLayout {
    enum Root {
        static func usesRegularDashboardLayout(
            presentation: InspectionPresentation,
            horizontalSizeClass: UserInterfaceSizeClass?
        ) -> Bool {
            guard presentation == .app else {
                return false
            }

            #if os(macOS)
            return true
            #else
            return horizontalSizeClass == .regular
            #endif
        }

        static func contentMaxWidth(usesRegularDashboardLayout: Bool) -> CGFloat? {
            usesRegularDashboardLayout ? 1480 : PlatformValues.current.rootCompactContentMaxWidth
        }

        static func horizontalPadding(usesRegularDashboardLayout: Bool) -> CGFloat {
            usesRegularDashboardLayout ? 32 : PlatformValues.current.rootCompactHorizontalPadding
        }

        static var stackSpacing: CGFloat { PlatformValues.current.rootStackSpacing }
        static var sideRailWidth: CGFloat { PlatformValues.current.rootSideRailWidth }
    }

    enum Input {
        static func usesRegularWidthLayout(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
            #if os(macOS)
            return true
            #else
            return horizontalSizeClass == .regular
            #endif
        }

        static var usesHorizontalCompactDemoTargets: Bool { PlatformValues.current.inputUsesHorizontalCompactDemoTargets }
        static var usesInlineCompactInputControls: Bool { PlatformValues.current.inputUsesInlineCompactInputControls }
        static var inputPrompt: String { PlatformValues.current.inputPrompt }
        static var promptFont: Font { PlatformValues.current.inputPromptFont }
        static var cardSpacing: CGFloat { PlatformValues.current.inputCardSpacing }
        static var sampleColumnWidth: CGFloat { PlatformValues.current.inputSampleColumnWidth }
        static var demoTargetVerticalPadding: CGFloat { PlatformValues.current.inputDemoTargetVerticalPadding }
        static var demoTargetControlSize: ControlSize { PlatformValues.current.inputDemoTargetControlSize }
    }

    enum Chain {
        static var usesAnimatedDetailNavigation: Bool { PlatformValues.current.chainUsesAnimatedDetailNavigation }

        static var detailNavigationDelay: Duration? {
            usesAnimatedDetailNavigation ? .milliseconds(130) : nil
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

        static var inlineSearchButtonSize: CGFloat { 32 }
        static var scrollBottomContentPadding: CGFloat { 24 }
    }

    enum Diagnostics {
        static var contentMaxWidth: CGFloat { PlatformValues.current.diagnosticsContentMaxWidth }
    }
}
