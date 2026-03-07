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

### Completed

1. Navigation cleanup
2. Monitor screen cleanup
3. Host detail routing
4. Settings redesign
5. Proxy-era symbol cleanup
6. Dead runtime path removal
7. Runtime and extension simplification
8. Diagnostics model cleanup
9. Packet tunnel extension target rename
10. iOS simulator test target for Swift-side monitor/runtime tests

### 9. Validation and Safety

Every cleanup step should preserve:

1. manual inspect works
2. Safari/live traffic still works
3. monitor host list still updates
4. certificate detail still opens
5. live monitor can stop and restart

Validation loop after each cleanup:

1. `cargo test --manifest-path Rust/tunnel-core/Cargo.toml`
2. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'generic/platform=iOS Simulator' build | xcbeautify`
3. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'platform=iOS Simulator,id=<simulator-id>' test | xcbeautify`
4. targeted device smoke test only for changes that affect tunnel behavior

Current note:

1. The iOS test target intentionally covers the Swift-side runtime/monitor tests.
2. The heavier certificate parser fixture tests remain in SwiftPM for now.

## Immediate Next Step

Continue with product polish and feature work rather than structural cleanup.

Reason:

1. the runtime path is now explicitly one packet-tunnel runtime plus one Rust forwarding engine
2. the renamed packet tunnel extension works on device
3. `xcodebuild test -scheme Inspect` now runs the key Swift-side tests on simulator

## Future Network Work

### UDP and QUIC

Treat these as two different follow-ups:

1. UDP flow observation
2. QUIC/HTTP3 certificate capture

Scope:

1. UDP flow observation is moderate and can be added later by extending the `tun2proxy` observer seam and Inspect's adapter/store models.
2. QUIC/HTTP3 certificate capture is a separate, harder feature and should not be bundled into the basic UDP follow-up.

Implementation order:

1. Reintroduce UDP transport metadata in `tun2proxy` observer types.
2. Emit UDP session events from the `tun2proxy` UDP handling path.
3. Decide how Inspect should surface UDP observations in Monitor and Diagnostics.
4. Evaluate a dedicated QUIC strategy only after the TCP/UDP monitor product shape is stable.
