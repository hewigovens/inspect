import SwiftUI

struct InspectMacTunnelSmokeTestView: View {
    let configuration: InspectMacTunnelSmokeTestConfiguration

    @State private var runner: InspectMacTunnelSmokeTestRunner

    init(configuration: InspectMacTunnelSmokeTestConfiguration) {
        self.configuration = configuration
        _runner = State(initialValue: InspectMacTunnelSmokeTestRunner(configuration: configuration))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inspect macOS Packet Tunnel Smoke Test")
                .font(.title2.weight(.semibold))

            Text(runner.phaseTitle)
                .font(.headline)
                .foregroundStyle(runner.phaseColor)

            Text("Probe URL: \(configuration.probeURL.absoluteString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            ScrollView {
                Text(runner.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 540)
        .task {
            runner.startIfNeeded()
        }
    }
}
