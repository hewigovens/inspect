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

### 6. macOS Expansion

Goal:

Extend Inspect to macOS without forking the core monitor and certificate logic.

Done:

1. `Rust/tunnel-core` builds for `aarch64-apple-darwin` and `x86_64-apple-darwin`.
2. `InspectCore` and `InspectFeature` compile on macOS.
3. Swift package tests pass on macOS.
4. The shared SwiftUI layer now keeps macOS branching concentrated in one support layer instead of scattering it through feature views.
5. macOS deployment targets are declared in the Swift package and Xcode project source of truth.

Missing:

1. A real macOS app target in `project.yml`.
2. A macOS packet-tunnel extension target, plist, entitlements, signing, and bundle identifiers.
3. `LiveMonitorManager` wiring for a macOS packet-tunnel bundle identifier and preferences flow.
4. macOS-specific validation commands in `just` and CI.
5. A macOS share entry point for manual inspection handoff.

Decisions:

1. Do the macOS packet-tunnel extension target before macOS app-shell UI changes.
2. Treat packet-tunnel bring-up as the highest-risk and highest-value macOS task because Live Monitor depends on it.
3. Prefer a macOS Service / Share item for manual inspection input instead of recreating the current iOS action extension first.
4. The share entry point only needs to accept a URL or host and pass it into Inspect.

Execution Order:

1. Add the macOS packet-tunnel extension target with Rust linkage and signing scaffolding.
2. Validate tunnel start, stop, preferences save/load, and shared App Group feed/log behavior on macOS.
3. Add a macOS app target that reuses the existing SwiftUI Inspect / Monitor / Settings flows with minimal platform-specific polish.
4. Add the macOS Service / Share entry point for URL-or-host handoff into manual inspection.
5. Do macOS-specific UI polish, window behavior, screenshots, and menu integration only after the tunnel path is proven stable.

## Validation Loop

Use this validation loop for non-trivial changes:

1. `cargo test --manifest-path Rust/tunnel-core/Cargo.toml`
2. `swift test` in `Packages/InspectCore`
3. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'generic/platform=iOS Simulator' build | xcbeautify`
4. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'platform=iOS Simulator,id=<simulator-id>' test | xcbeautify`
5. targeted device smoke test when tunnel behavior, app-group logging, or monitor behavior changes
6. macOS packet-tunnel smoke test once the macOS extension target exists
7. macOS app smoke test once the macOS app target exists

## Near-Term Priorities

Next practical steps:

1. Continue UI polish on Monitor and Host Detail.
2. Keep the live-monitor tunnel path stable while improving diagnostics.
3. Add UDP observation through the `tun2proxy` observer branch.
4. Revisit QUIC only after UDP observation and product presentation are clear.
5. Build the macOS packet-tunnel target before spending time on a dedicated macOS app shell.
