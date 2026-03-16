import InspectKit
import SwiftUI
import WidgetKit

struct InspectLiveMonitorWidgetEntryView: View {
    let entry: InspectLiveMonitorEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            Text(entry.isEnabled ? "On" : "Off")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(statusTint)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 0)

            monitorToggle
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text("Monitor")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Circle()
                .fill(statusTint)
                .frame(width: 12, height: 12)
        }
    }

    private var monitorToggle: some View {
        Link(destination: InspectAppRoute.toggleLiveMonitor.url) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.78))

                    Text(entry.isEnabled ? "On" : "Off")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 8)

                ZStack(alignment: entry.isEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(entry.isEnabled ? statusTint.opacity(0.9) : Color.white.opacity(0.22))
                        .frame(width: 42, height: 25)

                    Circle()
                        .fill(.white)
                        .frame(width: 19, height: 19)
                        .padding(3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var widgetBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.13, blue: 0.23),
                    Color(red: 0.13, green: 0.14, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    statusTint.opacity(0.28),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 12,
                endRadius: 180
            )
        }
    }

    private var statusTint: Color {
        entry.isEnabled ? Color.green.opacity(0.94) : Color.orange.opacity(0.94)
    }
}
