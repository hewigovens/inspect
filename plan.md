# Inspect Cleanup Plan

## Product Direction

Inspect should feel like one product with two core jobs:

1. Manual certificate inspection
2. Passive system-wide host and certificate monitoring

The app should be organized around a small set of stable concepts:

1. Host
2. Observation
3. Report
4. Certificate
5. Tunnel

Manual inspect and live monitor should both converge on the same `TLSInspectionReport` model.

## Target Navigation

### Tabs

Keep only three top-level tabs:

1. Inspect
2. Monitor
3. Settings

Remove `Logs` as a top-level tab. Logs are diagnostics, not core navigation.

### Inspect

Purpose:

1. Enter host or URL
2. Run one-shot inspection
3. View report summary
4. Open certificate detail
5. Access recent lookups

### Monitor

Purpose:

1. Turn live monitor on/off
2. See tunnel health and activity
3. Browse a host-centered inventory
4. Open host detail
5. Open certificate detail from host detail

Primary layout:

1. Live Monitor card
2. Host list directly below the card
3. Diagnostics entry point at the bottom

Do not lead with raw event history on the main monitor screen.

### Settings

Purpose:

1. Show tunnel/config status
2. Provide diagnostics and log export
3. Show app version/about
4. Link to App Store rating

Visual direction:

Follow the row-label style from `/Users/hewig/workspace/h/AnyTime/App/Features/SettingsView.swift`:

1. Rounded square icon tile
2. Section-based grouped layout
3. Clear trailing affordances
4. Diagnostics treated as a first-class settings section

## Target Information Architecture

### Main Models

1. `TLSFlowObservation`
   - raw passive event
2. `TLSInspectionReport`
   - normalized inspection result
3. `InspectionMonitoredHost`
   - host-centered aggregation of latest report + latest event + status
4. `Host Detail`
   - screen model built from a monitored host and related history

### Host Detail Screen

This should become the monitor destination instead of jumping straight from the list into certificate detail.

Host Detail should show:

1. Host name
2. Latest trust badge
3. Last seen time
4. Endpoint and SNI summary
5. Latest certificate chain summary
6. Button/link to full `CertificateDetailView`
7. Recent observation timeline
8. Optional `Inspect Again` action

## Simplification Decisions

These are the constraints for cleanup work.

1. Preserve the currently working tunnel path.
2. Do not reintroduce proxy-based fallback paths into the main flow.
3. Keep direct DNS as the active iOS path unless a later regression forces reconsideration.
4. Keep the packet tunnel extension thin.
5. Keep Rust as the forwarding/observation core.
6. Keep one diagnostics/logging path through the shared app group log.

## Cleanup Order

### 1. Navigation Cleanup

Goal:

Reduce top-level complexity and move diagnostics out of the main tab bar.

Tasks:

1. Remove `Logs` tab from `InspectAppRootView`
2. Add `Diagnostics` destination inside `Settings`
3. Move current log viewer into that destination
4. Keep copy/clear/export actions in diagnostics

Done when:

1. Top-level tabs are `Inspect`, `Monitor`, `Settings`
2. Logs are still accessible from Settings

### 2. Monitor Screen Cleanup

Goal:

Make Monitor host-centered instead of event-centered.

Tasks:

1. Keep the Live Monitor card at the top
2. Add a dedicated host list below the card
3. Remove the raw event list from the main monitor surface
4. Add a `Diagnostics` section or button at the bottom for raw events/logs
5. Keep host count and last activity visible near the top

Done when:

1. Monitor reads like a host inventory, not a debug feed
2. Event history is still available, but secondary

### 3. Host Detail

Goal:

Make host rows open a proper detail screen.

Tasks:

1. Introduce `HostDetailView`
2. Route monitor host taps to `HostDetailView`
3. Show latest report summary in host detail
4. Show recent observations for that host
5. Link from host detail to `CertificateDetailView`

Done when:

1. Monitor list is a stable browsing surface
2. Certificate detail becomes one level deeper and more intentional

### 4. Settings Redesign

Goal:

Adopt the cleaner AnyTime-style settings structure.

Tasks:

1. Replace plain SF Symbol rows with icon-tile labels
2. Add sections:
   - Tunnel
   - Diagnostics
   - About
3. Move log viewer/export into Diagnostics
4. Show error state more cleanly
5. Keep version/about/rate links in About

Done when:

1. Settings feels like product UI, not temporary admin UI

### 5. Rename Proxy-Era Types

Goal:

Match names to the actual architecture.

Tasks:

1. Rename `AppProxyManager` to `LiveMonitorManager`
2. Rename any remaining `AppProxy`-named Swift symbols that no longer represent an app proxy
3. Keep target names, bundle identifiers, entitlements, and extension product names stable until signing/profiles are intentionally migrated

Important:

1. Rename code symbols first
2. Delay risky target/product renames until after UI cleanup and another device pass

Done when:

1. Source symbols match packet tunnel reality
2. Provisioning-sensitive identifiers remain unchanged until a deliberate migration

### 6. Remove Dead Runtime Paths

Goal:

Delete code from abandoned pivots.

Candidates:

1. `Tun2SocksKit` SwiftPM dependency
2. `LocalConnectProxyServer`
3. `LocalSocks5Server`
4. `Tun2SocksForwardingEngine`
5. Old proxy-port-specific plumbing that is no longer part of the live path
6. Forwarding-engine selector code now that Rust is the only supported path

Tasks:

1. Verify each candidate is unused
2. Remove `Tun2SocksKit` from SwiftPM and lockfiles
3. Remove the dead local relay/proxy files
4. Remove old proxy-port-specific config, logs, and selector code

Done when:

1. There is one active forwarding path
2. No confusing proxy-era leftovers remain

### 7. Runtime/Extension Simplification

Goal:

Make the extension wrapper minimal and the core runtime easier to reason about.

Tasks:

1. Keep `InspectPacketTunnelRuntime` as the shared orchestration layer
2. Keep `RustTunnelForwardingEngine` as the active engine
3. Remove engine-selection complexity if no longer needed
4. Make config explicit:
   - tunnel addresses
   - DNS servers
   - MTU
   - monitoring enabled
5. Audit whether fake IP range is still needed in the direct-DNS path

Done when:

1. The extension starts one runtime path only
2. Device logs are easier to read

### 8. Diagnostics Model Cleanup

Goal:

Separate product-facing state from debug-facing state.

Tasks:

1. Keep `entries` for diagnostics/history
2. Keep `monitoredHosts` for the primary monitor UI
3. Add lightweight host activity summaries:
   - first seen
   - last seen
   - latest trust state
   - latest cert availability
4. Avoid surfacing raw probe failure wording in the main host list unless needed

Done when:

1. Diagnostics remains powerful
2. Main UI remains clean

### 9. Validation and Safety

Every cleanup step should preserve:

1. manual inspect works
2. Safari/live traffic still works
3. monitor host list still updates
4. certificate detail still opens
5. live monitor can stop and restart

Validation loop after each cleanup:

1. `cargo test --manifest-path Rust/inspect-tunnel-core/Cargo.toml`
2. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'generic/platform=iOS Simulator' build | xcbeautify`
3. targeted device smoke test only for changes that affect tunnel behavior

## Immediate Next Step

Continue with `7. Runtime/Extension Simplification`.

Reason:

1. navigation cleanup, host detail, dead runtime cleanup, and symbol rename are already in place
2. the remaining architecture work is now about reducing configuration noise, not changing behavior
3. target and bundle renames should still wait until after another device pass
