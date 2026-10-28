import SwiftUI

/// Layout facts read from the view's own geometry rather than the device.
///
/// On iPhone Duo the app resizes as the device folds, unfolds, or enters Split View,
/// so layout decisions read the live container instead of the screen or orientation.
struct InspectFoldMetrics: Equatable, Sendable {
    static let none = InspectFoldMetrics(availableSize: nil, divisionFrame: nil)

    let availableSize: CGSize?
    let divisionFrame: CGRect?

    var isPartiallyFolded: Bool {
        divisionFrame != nil
    }

    /// Width content may occupy without straddling a book-style fold.
    ///
    /// A hinge resting under the device divides height instead of width, so the full
    /// container width stays usable in that posture.
    var contentWidth: CGFloat? {
        guard let availableSize else {
            return nil
        }

        guard let divisionFrame, dividesWidth(divisionFrame) else {
            return availableSize.width
        }

        return divisionFrame.minX
    }

    /// Alignment matching `contentWidth`, so content stays in the region it was sized for.
    var contentAlignment: Alignment {
        guard let divisionFrame, dividesWidth(divisionFrame) else {
            return .center
        }

        return .leading
    }

    private func dividesWidth(_ frame: CGRect) -> Bool {
        frame.height > frame.width
    }
}

extension View {
    /// Reports the container size plus the active fold, when the runtime provides one.
    func inspectFoldMetrics(_ onChange: @escaping (InspectFoldMetrics) -> Void) -> some View {
        onGeometryChange(for: InspectFoldMetrics.self) { proxy in
            var divisionFrame: CGRect?
            #if os(iOS)
                if #available(iOS 27.1, *) {
                    divisionFrame = proxy.reservedRegions(kind: .division).first?.frame
                }
            #endif

            return InspectFoldMetrics(
                availableSize: proxy.size,
                divisionFrame: divisionFrame
            )
        } action: { metrics in
            onChange(metrics)
        }
    }

    /// Keeps content inside the region the fold leaves available.
    func inspectFoldSafe(_ metrics: InspectFoldMetrics) -> some View {
        frame(maxWidth: metrics.contentWidth)
            .frame(maxWidth: .infinity, alignment: metrics.contentAlignment)
    }
}
