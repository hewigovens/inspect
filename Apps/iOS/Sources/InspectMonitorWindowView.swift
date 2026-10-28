import InspectKit
import SwiftUI

/// Second scene for iPhone Duo's inner display.
///
/// Duo is the first iPhone that can show more than one instance of an app, so the
/// monitor gets its own window and can sit beside Inspect while both stay live.
/// `InspectionMonitorView` refreshes on appear, so this only supplies the action.
struct InspectMonitorWindowView: View {
    @State private var manager = LiveMonitorManager.shared

    var body: some View {
        InspectionMonitorView {
            await manager.refresh()
        }
    }
}
