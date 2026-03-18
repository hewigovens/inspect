# Inspect

[![CI](https://github.com/hewigovens/inspect/actions/workflows/ci.yml/badge.svg)](https://github.com/hewigovens/inspect/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138.svg)](https://swift.org)
[![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)](#license)
[![DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/hewigovens/inspect)

Inspect is a TLS certificate inspector for iPhone, iPad, and macOS.

It supports:

- manual inspection of a host or HTTPS URL
- passive live monitoring through the packet tunnel flow
- Safari extensions on iOS and macOS for inspecting the current page
- a macOS share extension that hands shared pages into the app

## Highlights

- Inspect a host name or HTTPS URL directly in the app.
- Open Inspect Certificate from Safari on iPhone, iPad, and macOS.
- Open certificate detail directly from Safari extension handoff.
- Capture the presented trust chain from a live TLS handshake.
- Decode X.509 fields including SANs, EKUs, key usage, AIA, SKI/AKI, policies, fingerprints, and public key details.
- Surface security findings for trust failures, hostname mismatch, expired certificates, weak crypto, suspicious CA usage, and common interception products.
- Export DER certificates from the chain.

## Repository Layout

- `Apps/iOS/`: iOS app shell and iOS settings
- `Apps/macOS/`: macOS app shell and macOS settings
- `Extensions/Action/`: iOS action/share extension
- `Extensions/ActionShared/`: shared action-extension support
- `Extensions/SafariWeb/`: Safari web extension for iOS and macOS
- `Extensions/MacShare/`: macOS share extension
- `Extensions/PacketTunnel/`: iOS/macOS packet tunnel wrapper and Rust bridge
- `Packages/InspectCore/`: shared Swift models, features, UI, logging, and tests
- `Rust/tunnel-core/`: Rust forwarding core

## Getting Started

Requirements:

- Xcode 16 or newer
- iOS 18 SDK
- XcodeGen
- `xcbeautify`

Generate the project:

```bash
just generate
```

Open it:

```bash
open Inspect.xcodeproj
```

## Development

Detailed development notes live in [DEVELOPMENT.md](DEVELOPMENT.md).

Useful commands:

```bash
just generate
just test-ios-sim
just run-mac
just rust test
just testflight-dry-run
```

## License

Inspect is licensed under GPLv3. See [LICENSE](LICENSE).
