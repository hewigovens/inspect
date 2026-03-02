import SwiftUI

public enum InspectionPresentation: Sendable, Equatable {
    case app
    case actionExtension

    var topPadding: CGFloat {
        self == .actionExtension ? 8 : 16
    }
}
