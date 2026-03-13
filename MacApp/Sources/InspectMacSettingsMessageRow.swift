import SwiftUI

struct InspectMacSettingsMessageRow: View {
    let message: String
    let systemImage: String
    let foregroundStyle: AnyShapeStyle

    init(message: String, systemImage: String, color: Color) {
        self.message = message
        self.systemImage = systemImage
        foregroundStyle = AnyShapeStyle(color)
    }

    init(message: String, systemImage: String, hierarchicalStyle: HierarchicalShapeStyle) {
        self.message = message
        self.systemImage = systemImage
        foregroundStyle = AnyShapeStyle(hierarchicalStyle)
    }

    var body: some View {
        Label(message, systemImage: systemImage)
            .foregroundStyle(foregroundStyle)
    }
}
