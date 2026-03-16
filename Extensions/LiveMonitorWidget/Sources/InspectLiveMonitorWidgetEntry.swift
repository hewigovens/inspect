import InspectKit
import WidgetKit

struct InspectLiveMonitorEntry: TimelineEntry {
    let date: Date
    let isEnabled: Bool
}

struct InspectLiveMonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> InspectLiveMonitorEntry {
        InspectLiveMonitorEntry(date: .now, isEnabled: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (InspectLiveMonitorEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InspectLiveMonitorEntry>) -> Void) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300))))
    }

    private func currentEntry() -> InspectLiveMonitorEntry {
        InspectLiveMonitorEntry(
            date: .now,
            isEnabled: InspectionLiveMonitorPreferenceStore.isEnabled
        )
    }
}
