@testable import InspectKit
import CoreGraphics
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
func regularWidthTrustsSizeClassWithoutGeometry() {
    #expect(
        InspectLayout.fitsRegularWidth(
            nil,
            minimum: 900,
            horizontalSizeClass: .regular
        )
    )
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
