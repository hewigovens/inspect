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
8. A native macOS app target exists and reuses the shared Inspect, Monitor, and Settings flows.
9. A macOS packet-tunnel extension target exists and Live Monitor wiring is in place on macOS.
10. iOS and macOS App Store packaging, upload, and review-submission flows are working.
11. Safari extensions exist on iOS and macOS for current-page inspection.
12. A macOS share extension exists and opens shared pages directly into certificate detail.

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
2. Polish host detail and certificate-detail transitions, especially on regular-width layouts.
3. Keep diagnostics useful without leaking low-level implementation details into the main UI.
4. Keep iOS, iPad, and macOS presentation aligned without stretching phone-first layouts onto larger screens.
5. Keep extension naming and handoff behavior consistent across iOS Safari, macOS Safari, and macOS Share.

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
2. Keep device, simulator, and macOS workflows documented.
3. Keep iOS and macOS TestFlight / App Review flows easy to run from `just` and repo scripts.
4. Keep store descriptions and screenshots current without intrusive in-app screenshot automation.

### 6. macOS Expansion

Goal:

Extend Inspect to macOS without forking the core monitor and certificate logic.

Done:

1. `Rust/tunnel-core` builds for `aarch64-apple-darwin` and `x86_64-apple-darwin`.
2. `InspectCore` and the shared SwiftUI feature layer compile on macOS.
3. Swift package tests pass on macOS.
4. A real `InspectMac` app target exists in `project.yml`.
5. A macOS packet-tunnel extension target, plist, entitlements, signing, and bundle identifiers are in place.
6. Live Monitor wiring exists on macOS and shares the same core monitor and certificate logic.
7. The shared SwiftUI layer now keeps macOS branching concentrated in platform files and shared layout/theme helpers instead of scattering it through feature views.
8. macOS deployment targets are declared in the Swift package and Xcode project source of truth.
9. macOS build, packaging, upload, screenshots, and App Review submission flows are proven.
10. A macOS share extension exists and hands shared pages into the app's certificate-detail flow.
11. Safari extension current-page inspection and full-detail handoff work on both iOS and macOS.

Remaining:

1. Continued regular-width polish for Inspect, Monitor, and certificate detail.
2. Mac-specific validation coverage in CI where it adds signal.
3. Decide whether the old iOS action extension should remain alongside Safari extension, be simplified, or be removed.

Decisions:

1. Keep macOS on the same shared feature stack as iOS unless a platform difference is clearly product-driven.
2. Prefer platform-specific files or shared layout/theme helpers over scattered `#if os(...)` branches.
3. Prefer direct handoff entry points that land in the existing shared Inspect flows instead of building extension-specific certificate UI.
4. Keep the Safari extension as the primary current-page entry point and the macOS share extension as the primary system share entry point.

Execution Order:

1. Continue regular-width and macOS-specific UI polish now that the tunnel path is proven.
2. Add CI coverage only for macOS checks that catch real regressions.
3. Reassess extension surface area after Safari extension and macOS share extension usage settles.

## Validation Loop

Use this validation loop for non-trivial changes:

1. `cargo test --manifest-path Rust/tunnel-core/Cargo.toml`
2. `swift test` in `Packages/InspectCore`
3. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'generic/platform=iOS Simulator' build | xcbeautify`
4. `xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination 'platform=iOS Simulator,id=<simulator-id>' test | xcbeautify`
5. `xcodebuild -project Inspect.xcodeproj -scheme InspectMac -destination 'platform=macOS' build | xcbeautify`
6. targeted device smoke test when tunnel behavior, app-group logging, or monitor behavior changes
7. macOS smoke test when tunnel behavior, window behavior, or App Group logging changes

## Near-Term Priorities

Next practical steps:

1. Continue regular-width polish on Inspect, Monitor, and certificate detail.
2. Keep the live-monitor tunnel path stable on both iOS and macOS while improving diagnostics only where they help users.
3. Add UDP observation through the `tun2proxy` observer branch.
4. Add targeted CI coverage for macOS app and extension regressions where it adds real signal.
5. Decide the long-term role of the old iOS action extension now that Safari extension handoff exists.
6. Revisit QUIC only after UDP observation and product presentation are clear.
