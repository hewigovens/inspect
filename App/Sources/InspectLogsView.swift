import InspectCore
import SwiftUI
import UIKit

struct InspectLogsView: View {
    @State private var logText = "No tunnel log yet. Start Live Monitor to generate logs."
    @State private var autoRefresh = true
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .background(Color(.systemGroupedBackground))
                .onChange(of: logText) { _, _ in
                    guard autoRefresh else {
                        return
                    }

                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = logText
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }

                    Button {
                        clearLog()
                    } label: {
                        Image(systemName: "trash")
                    }

                    Toggle(isOn: $autoRefresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .toggleStyle(.button)
                }
            }
            .task {
                loadLog()
            }
            .onReceive(timer) { _ in
                guard autoRefresh else {
                    return
                }

                loadLog()
            }
        }
    }

    private func loadLog() {
        DispatchQueue.global(qos: .utility).async {
            let text = InspectSharedLog.readTail()
            DispatchQueue.main.async {
                logText = text ?? "No tunnel log yet. Start Live Monitor to generate logs."
            }
        }
    }

    private func clearLog() {
        DispatchQueue.global(qos: .utility).async {
            InspectSharedLog.reset()
            DispatchQueue.main.async {
                logText = "Tunnel log cleared."
            }
        }
    }
}
