import InspectKit
import SwiftUI

struct InspectMonitorWindowView: View {
    @State private var manager = LiveMonitorManager.shared

    var body: some View {
        InspectionMonitorView {
            await manager.refresh()
        }
    }
}
