import InspectKit
import SwiftUI
import WidgetKit

struct InspectLiveMonitorWidget: Widget {
    let kind = InspectWidgetKind.liveMonitor

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InspectLiveMonitorProvider()) { entry in
            InspectLiveMonitorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Live Monitor")
        .description("Quickly jump in and toggle Live Monitor.")
        .contentMarginsDisabled()
        .supportedFamilies([.systemSmall])
    }
}
