import SwiftUI

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
            usesRegularDashboardLayout ? 1480 : compactContentMaxWidth
        }

        static func horizontalPadding(usesRegularDashboardLayout: Bool) -> CGFloat {
            if usesRegularDashboardLayout {
                return 32
            }

            return compactHorizontalPadding
        }

        static var stackSpacing: CGFloat {
            #if os(macOS)
            16
            #else
            18
            #endif
        }

        static var sideRailWidth: CGFloat {
            #if os(macOS)
            380
            #else
            360
            #endif
        }

        private static var compactContentMaxWidth: CGFloat? {
            #if os(macOS)
            1140
            #else
            nil
            #endif
        }

        private static var compactHorizontalPadding: CGFloat {
            #if os(macOS)
            28
            #else
            20
            #endif
        }
    }

    enum Input {
        static func usesRegularWidthLayout(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
            #if os(macOS)
            return true
            #else
            return horizontalSizeClass == .regular
            #endif
        }

        static var usesHorizontalCompactDemoTargets: Bool {
            #if os(macOS)
            true
            #else
            false
            #endif
        }

        static var usesInlineCompactInputControls: Bool {
            #if os(macOS)
            true
            #else
            false
            #endif
        }

        static var inputPrompt: String {
            #if os(macOS)
            "Inspect a host name or HTTPS URL."
            #else
            "Enter a host name or HTTPS URL."
            #endif
        }

        static var promptFont: Font {
            #if os(macOS)
            .inspectRootCaptionSemibold
            #else
            .inspectRootSubheadline
            #endif
        }

        static var cardSpacing: CGFloat {
            #if os(macOS)
            12
            #else
            14
            #endif
        }

        static var sampleColumnWidth: CGFloat {
            #if os(macOS)
            320
            #else
            300
            #endif
        }

        static var demoTargetVerticalPadding: CGFloat {
            #if os(macOS)
            6
            #else
            8
            #endif
        }

        static var demoTargetControlSize: ControlSize {
            #if os(macOS)
            .small
            #else
            .regular
            #endif
        }
    }

    enum Chain {
        static var usesAnimatedDetailNavigation: Bool {
            #if os(macOS)
            true
            #else
            false
            #endif
        }

        static var detailNavigationDelay: Duration? {
            usesAnimatedDetailNavigation ? .milliseconds(130) : nil
        }
    }
}
