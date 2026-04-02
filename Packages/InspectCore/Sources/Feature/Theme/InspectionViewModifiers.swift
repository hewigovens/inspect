import SwiftUI

extension View {
    func inspectURLField() -> some View {
        inspectPlatformURLField()
    }

    @ViewBuilder
    func applyExtensionScrollMargins(_ presentation: InspectionPresentation) -> some View {
        if presentation == .actionExtension {
            contentMargins(.top, 0, for: .scrollContent)
        } else {
            self
        }
    }

    func hideRootNavigationBar() -> some View {
        inspectNavigationBarHidden()
    }

    func inlineRootNavigationTitle() -> some View {
        inspectInlineNavigationTitle()
    }

    func extensionGroupedListStyle() -> some View {
        inspectGroupedListStyle(background: InspectPlatform.groupedBackground)
    }
}
