import InspectKit
import InspectCore
@preconcurrency import NetworkExtension
import SwiftUI

struct InspectMacVerificationHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Packet Tunnel Verification")
                .font(.largeTitle.weight(.semibold))

            Text("Install the Inspect VPN profile, enable it from System Settings > VPN if needed, then start the tunnel here and confirm the tunnel log begins recording traffic.")
                .foregroundStyle(.secondary)
        }
    }
}

struct InspectMacVerificationProfileCard: View {
    let status: String
    let isConfigured: Bool

    var body: some View {
        GroupBox {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Connection")
                        .foregroundStyle(.secondary)
                    Text(status)
                        .fontWeight(.medium)
                }

                GridRow {
                    Text("Configured")
                        .foregroundStyle(.secondary)
                    Text(isConfigured ? InspectionCommonStrings.yes : InspectionCommonStrings.no)
                        .fontWeight(.medium)
                }

                GridRow {
                    Text("Provider")
                        .foregroundStyle(.secondary)
                    Text(InspectMacVerificationManager.providerBundleIdentifier)
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("App Group")
                        .foregroundStyle(.secondary)
                    Text(InspectSharedContainer.appGroupIdentifier)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        } label: {
            Text("VPN Profile")
        }
    }
}

struct InspectMacVerificationActionRow: View {
    let isConfigured: Bool
    let status: NEVPNStatus
    let installProfile: () -> Void
    let refresh: () -> Void
    let startTunnel: () -> Void
    let stopTunnel: () -> Void
    let openSystemSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Install VPN Profile", action: installProfile)
            Button("Refresh Status", action: refresh)

            Button("Start Tunnel", action: startTunnel)
                .disabled(isConfigured == false || status == .connected || status == .connecting || status == .reasserting)

            Button("Stop Tunnel", action: stopTunnel)
                .disabled(status == .disconnected || status == .disconnecting || status == .invalid)

            Button("Open System Settings", action: openSystemSettings)
        }
    }
}

struct InspectMacVerificationChecklist: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested verification path")
                .font(.headline)

            Text("1. Click Install VPN Profile.")
            Text("2. Open System Settings and confirm Inspect appears in VPN.")
            Text("3. Enable or connect the Inspect VPN profile if macOS prompts for approval.")
            Text("4. Click Start Tunnel here if it is still disconnected.")
            Text("5. Open the Tunnel Log tab and confirm start-up messages appear.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
