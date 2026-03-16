import InspectCore
import InspectKit
import SwiftUI

struct InspectMacVerificationRootView: View {
    var body: some View {
        TabView {
            InspectMacVerificationView()
                .tabItem {
                    Label("Verify", systemImage: "checkmark.shield")
                }

            InspectionTunnelLogView()
                .tabItem {
                    Label("Tunnel Log", systemImage: "doc.text.magnifyingglass")
                }
        }
        .frame(minWidth: 880, minHeight: 620)
    }
}

@MainActor
private struct InspectMacVerificationView: View {
    @State private var manager = InspectMacVerificationManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InspectMacVerificationHeader()

            InspectMacVerificationProfileCard(
                status: manager.status.inspectionDescription,
                isConfigured: manager.isConfigured
            )

            InspectMacVerificationActionRow(
                isConfigured: manager.isConfigured,
                status: manager.status,
                installProfile: {
                    Task {
                        await manager.installProfile()
                    }
                },
                refresh: {
                    Task {
                        await manager.refresh()
                    }
                },
                startTunnel: {
                    Task {
                        await manager.startTunnel()
                    }
                },
                stopTunnel: {
                    Task {
                        await manager.stopTunnel()
                    }
                },
                openSystemSettings: {
                    manager.openSystemSettings()
                }
            )

            if let actionMessage = manager.actionMessage {
                Text(actionMessage)
                    .foregroundStyle(.secondary)
            }

            if let lastErrorMessage = manager.lastErrorMessage {
                Text(lastErrorMessage)
                    .foregroundStyle(.red)
            }

            InspectMacVerificationChecklist()

            Spacer(minLength: 0)
        }
        .padding(24)
        .task {
            await manager.refresh()
        }
    }
}
