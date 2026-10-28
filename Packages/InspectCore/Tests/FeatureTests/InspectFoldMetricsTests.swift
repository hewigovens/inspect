import CoreGraphics
@testable import InspectKit
import Testing

@Test
func regularWidthRequiresRegularSizeClass() {
    #expect(
        InspectLayout.fitsRegularWidth(
            1200,
            minimum: 900,
            horizontalSizeClass: .compact
        ) == false
    )
}

@Test
func regularWidthRejectsContainersBelowMinimum() {
    #expect(
        InspectLayout.fitsRegularWidth(
            626,
            minimum: 900,
            horizontalSizeClass: .regular
        ) == false
    )
}

@Test
func regularWidthAcceptsContainersAtOrAboveMinimum() {
    #expect(
        InspectLayout.fitsRegularWidth(
            900,
            minimum: 900,
            horizontalSizeClass: .regular
        )
    )
}

@Test
func regularWidthTrustsSizeClassBeforeGeometry() {
    #expect(
        InspectLayout.fitsRegularWidth(
            nil,
            minimum: 900,
            horizontalSizeClass: .regular
        )
    )
}

@Test
func inputCardFitsAtItsGateWidth() {
    // The regular input card has hard minimums: 278pt of buttons, a sample
    // column, and spacing. The gate must never admit a width below them.
    let gate = InspectLayout.Input.regularWidthMinimum
    let rootPadding: CGFloat = 64
    let cardPadding: CGFloat = 36
    let columnsNeeded: CGFloat = 116 + 12 + 150 + 20 + 240

    #expect(gate - rootPadding - cardPadding >= columnsNeeded)
}

@Test
func dashboardStaysCompactOnNarrowRegularWidths() {
    // Duo inner display: regular width in portrait, but too narrow for the rail.
    #expect(
        InspectLayout.fitsRegularWidth(
            InspectLayout.Root.dashboardMinimumWidth - 1,
            minimum: InspectLayout.Root.dashboardMinimumWidth,
            horizontalSizeClass: .regular
        ) == false
    )
    #expect(
        InspectLayout.fitsRegularWidth(
            InspectLayout.Root.dashboardMinimumWidth,
            minimum: InspectLayout.Root.dashboardMinimumWidth,
            horizontalSizeClass: .regular
        )
    )
}

@Test
func dashboardIsDisabledOutsideTheApp() {
    #expect(
        InspectLayout.Root.usesRegularDashboardLayout(
            presentation: .actionExtension,
            horizontalSizeClass: .regular,
            availableWidth: 1200
        ) == false
    )
}

/// Widths measured from the iPhone Duo simulator. The unfolded landscape value
/// (867pt) previously fell under the dashboard threshold and lost its two columns.
@Test(
    arguments: [
        (585.0, false, "unfolded portrait"),
        (744.0, true, "iPad mini portrait"),
        (834.0, true, "iPad Pro 11 portrait"),
        (867.0, true, "unfolded landscape"),
        (1024.0, true, "iPad Pro 12.9 portrait"),
    ]
)
func dashboardMatchesRealDeviceWidths(width: Double, expectsDashboard: Bool, label: String) {
    #expect(
        InspectLayout.fitsRegularWidth(
            CGFloat(width),
            minimum: InspectLayout.Root.dashboardMinimumWidth,
            horizontalSizeClass: .regular
        ) == expectsDashboard,
        "\(label) at \(Int(width))pt"
    )
}

@Test
func inputCardDropsToCompactControlsOnNarrowRegularWidths() {
    #expect(
        InspectLayout.fitsRegularWidth(
            InspectLayout.Input.regularWidthMinimum - 1,
            minimum: InspectLayout.Input.regularWidthMinimum,
            horizontalSizeClass: .regular
        ) == false
    )
    #expect(
        InspectLayout.fitsRegularWidth(
            InspectLayout.Input.regularWidthMinimum,
            minimum: InspectLayout.Input.regularWidthMinimum,
            horizontalSizeClass: .regular
        )
    )
}

@Test
func sideRailShrinksWithTheContainer() {
    let full = InspectLayout.Root.sideRailWidth

    #expect(InspectLayout.Root.sideRailWidth(forAvailableWidth: nil) == full)
    #expect(InspectLayout.Root.sideRailWidth(forAvailableWidth: 2400) == full)
    #expect(InspectLayout.Root.sideRailWidth(forAvailableWidth: 867) < full)
    #expect(InspectLayout.Root.sideRailWidth(forAvailableWidth: 744) < full)
}

/// The rail must leave the main column usable at every width that allows a dashboard.
@Test
func sideRailLeavesMainColumnUsable() {
    for width in [700.0, 744.0, 834.0, 867.0, 1024.0] {
        let rail = InspectLayout.Root.sideRailWidth(forAvailableWidth: CGFloat(width))
        let mainColumn = width - 2 * 32 - rail - 18

        #expect(mainColumn >= 340, "main column \(Int(mainColumn))pt at \(Int(width))pt")
    }
}

@Test
func unfoldedLayoutKeepsFullContentWidth() {
    let metrics = InspectFoldMetrics(
        availableSize: CGSize(width: 890, height: 626),
        divisionFrame: nil
    )

    #expect(metrics.isPartiallyFolded == false)
    #expect(metrics.contentWidth == 890)
    #expect(metrics.contentAlignment == .center)
}

@Test
func bookStyleFoldConstrainsContentToLeadingRegion() {
    let metrics = InspectFoldMetrics(
        availableSize: CGSize(width: 890, height: 626),
        divisionFrame: CGRect(x: 430, y: 0, width: 30, height: 626)
    )

    #expect(metrics.isPartiallyFolded)
    #expect(metrics.contentWidth == 430)
    #expect(metrics.contentAlignment == .leading)
}

@Test
func horizontalFoldLeavesFullWidthUsable() {
    // Propped up: the hinge divides height, so width stays whole.
    let metrics = InspectFoldMetrics(
        availableSize: CGSize(width: 626, height: 890),
        divisionFrame: CGRect(x: 0, y: 430, width: 626, height: 30)
    )

    #expect(metrics.isPartiallyFolded)
    #expect(metrics.contentWidth == 626)
    #expect(metrics.contentAlignment == .center)
}

@Test
func missingGeometryReportsNoConstraints() {
    let metrics = InspectFoldMetrics.none

    #expect(metrics.isPartiallyFolded == false)
    #expect(metrics.contentWidth == nil)
    #expect(metrics.contentAlignment == .center)
}
