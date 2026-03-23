# Contributing to Inspect

## Requirements

- Xcode 16 or newer
- iOS 18 SDK
- XcodeGen
- `xcbeautify`

## Development setup

```bash
just generate
open Inspect.xcodeproj
```

## Common commands

```bash
just generate
just test-ios-sim
just run-mac
just rust test
just testflight-dry-run
```

See also [DEVELOPMENT.md](DEVELOPMENT.md) for detailed notes.

## Repository layout

- `Apps/iOS/` — iOS app shell and settings
- `Apps/macOS/` — macOS app shell and settings
- `Extensions/Action/` — iOS action/share extension
- `Extensions/ActionShared/` — shared action-extension support
- `Extensions/SafariWeb/` — Safari web extension for iOS and macOS
- `Extensions/MacShare/` — macOS share extension
- `Extensions/PacketTunnel/` — iOS/macOS packet tunnel wrapper and Rust bridge
- `Packages/InspectCore/` — shared Swift models, features, UI, logging, and tests
- `Rust/tunnel-core/` — Rust forwarding core
