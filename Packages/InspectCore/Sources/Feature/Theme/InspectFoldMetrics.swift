import SwiftUI

struct InspectFoldMetrics: Equatable, Sendable {
    static let none = InspectFoldMetrics(availableSize: nil, divisionFrame: nil)

    let availableSize: CGSize?
    let divisionFrame: CGRect?

    var isPartiallyFolded: Bool {
        divisionFrame != nil
    }

    var contentWidth: CGFloat? {
        guard let availableSize else {
            return nil
        }

        guard let divisionFrame, dividesWidth(divisionFrame) else {
            return availableSize.width
        }

        return divisionFrame.minX
    }

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

    func inspectFoldSafe(_ metrics: InspectFoldMetrics) -> some View {
        frame(maxWidth: metrics.contentWidth)
            .frame(maxWidth: .infinity, alignment: metrics.contentAlignment)
    }
}
