# Inspect Plan

## Product Goals

Inspect has two product jobs:

1. Manual TLS certificate inspection
2. Passive system-wide host and certificate monitoring

Everything in the app should reinforce one of those jobs.

## Current Baseline

The current working baseline is:

1. Manual inspect works on device.
2. Live Monitor works on device through the packet tunnel.
3. Safari traffic reaches the tunnel path.
4. Hosts persist across launches.
5. Host detail and certificate detail are wired.
6. Diagnostics and shared tunnel logs are available in-app.
7. Simulator build and simulator test flows are in place.

## Architecture Direction

Keep these constraints stable:

1. Keep `InspectCore` as the shared Swift package for models, monitor state, UI, and runtime orchestration.
2. Keep `InspectPacketTunnelExtension` thin.
3. Keep `Rust/tunnel-core` as the forwarding and passive-observation core.
4. Keep `tun2proxy` as the forwarding base.
5. Keep one logging path through the shared App Group log.
6. Do not reintroduce proxy-based fallback paths into the main live-monitor flow.

## Active Workstreams

### 1. Product Polish

Focus:

1. Refine Inspect, Monitor, and Settings copy.
2. Polish host detail and certificate-detail transitions.
3. Keep diagnostics useful without leaking low-level implementation details into the main UI.
4. Improve launch and app-store presentation assets.

### 2. Tunnel Stability

Focus:

1. Preserve the current working iOS packet-tunnel path.
2. Keep restart/stop/start behavior reliable.
3. Improve error reporting only when it helps product-level diagnosis.
4. Avoid risky structural changes unless they clearly improve stability.

### 3. UDP Observation

Goal:

Add UDP flow observation without blocking current TCP/TLS monitoring.

Plan:

1. Extend the `tun2proxy` observer seam to expose UDP session metadata and payload direction.
2. Map UDP observer events into `tunnel-core` and then into Inspect's monitor pipeline.
3. Decide how UDP observations should appear in Monitor and Diagnostics.
4. Keep certificate detail disabled for UDP-only observations unless a later protocol-specific parser exists.

### 4. QUIC and HTTP/3

Treat this as a separate track from basic UDP observation.

Scope:

1. Determine what metadata is realistically observable.
2. Evaluate whether passive QUIC handshake parsing is worth the complexity.
3. Do not bundle QUIC certificate capture into the first UDP milestone.

### 5. Documentation and Release Hygiene

Focus:

1. Keep architecture docs current.
2. Keep the device and simulator workflows documented.
3. Keep TestFlight and screenshot flows easy to run from `just`.

## Validation Loop

Use this validation loop for non-trivial changes:

1. `cargo test --manifest-path Rust/tunnel-core/Cargo.toml`
2. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'generic/platform=iOS Simulator' build | xcbeautify`
3. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'platform=iOS Simulator,id=<simulator-id>' test | xcbeautify`
4. targeted device smoke test when tunnel behavior, app-group logging, or monitor behavior changes

## Near-Term Priorities

Next practical steps:

1. Continue UI polish on Monitor and Host Detail.
2. Keep the live-monitor tunnel path stable while improving diagnostics.
3. Add UDP observation through the `tun2proxy` observer branch.
4. Revisit QUIC only after UDP observation and product presentation are clear.
