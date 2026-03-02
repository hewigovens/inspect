# Inspect

Inspect is a certificate inspector for iPhone and iPad. This repository is the modern rewrite of the app, built with Swift 6, SwiftUI, Swift Package Manager, and XcodeGen.

The current codebase replaces the older UIKit/OpenSSL-style stack with a package-first architecture that uses Apple's platform trust engine, `URLSession`, and native Security APIs to inspect live HTTPS connections.

## Highlights

- Inspect a host name or HTTPS URL directly in the app.
- Open Inspect from the share sheet on a page in Safari.
- Capture the presented trust chain from a live TLS handshake.
- Decode X.509 certificate fields including SANs, EKUs, key usage, AIA, SKI/AKI, policies, fingerprints, and public key details.
- Surface security findings for trust failures, hostname mismatch, expired certificates, weak crypto, suspicious CA usage, and common interception products.
- Export DER certificates from the chain.

## Architecture

The project is split into a small iOS shell and a local Swift package:

- `App/`: the main iOS application target.
- `Extension/`: the action/share extension entry point.
- `Packages/InspectCore/Sources/Core/`: TLS capture, URL normalization, certificate parsing, data models, and security analysis.
- `Packages/InspectCore/Sources/Feature/`: SwiftUI views, state, and theming shared by the app and extension.
- `Packages/InspectCore/Tests/CoreTests/`: parser and security analysis tests built with Swift Testing.
- `project.yml`: XcodeGen source of truth for the Xcode project.

## Modern Rewrite Notes

This repository reflects a full rewrite around current Apple platform APIs and modern Swift conventions:

- SwiftUI for the app UI and extension UI.
- Swift Package Manager for the shared app logic.
- Swift 6 language mode.
- Swift Testing for package tests.
- `swift-certificates`, `swift-asn1`, and `swift-crypto` for X.509 parsing and test fixtures.
- Native `Security` and `URLSession` integration for trust evaluation and chain capture.

## Requirements

- Xcode 16 or newer
- iOS 18 SDK
- XcodeGen

## Getting Started

Generate the Xcode project:

```bash
xcodegen generate
```

`Inspect.xcodeproj` is generated from `project.yml` and is not intended to be committed.

Open the project:

```bash
open Inspect.xcodeproj
```

## Development

Run the package tests:

```bash
cd Packages/InspectCore
swift test
```

Build the app from the command line:

```bash
xcodebuild -scheme Inspect -project Inspect.xcodeproj -destination 'generic/platform=iOS Simulator' build
```

## TestFlight Uploads

This repo includes a `just testflight` flow that archives the app, exports an IPA, and uploads it with [`asc`](https://github.com/rudrankriyam/App-Store-Connect-CLI).

One-time setup:

```bash
cp Configs/LocalOverrides.xcconfig.example Configs/LocalOverrides.xcconfig
cp .env.example .env
asc auth login \
  --name "Inspect" \
  --key-id "ABC123XYZ" \
  --issuer-id "00000000-0000-0000-0000-000000000000" \
  --private-key /path/to/AuthKey_ABC123XYZ.p8
```

Then update `.env`. `ASC_APP_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_KEY_PATH` are required. If you also set `TESTFLIGHT_GROUP`, the command will distribute the processed build to that group after upload.

Run the full flow:

```bash
just testflight
```

Useful variants:

```bash
just testflight-build
just testflight-dry-run
```

Notes:

- `just testflight` regenerates `Inspect.xcodeproj` with XcodeGen before archiving.
- The archive/export flow uses automatic signing and `-allowProvisioningUpdates` by default. Set `TESTFLIGHT_ALLOW_PROVISIONING_UPDATES=false` in `.env` if you do not want that behavior.
- Set `TESTFLIGHT_BUILD_NUMBER` in `.env` when you need to override `CURRENT_PROJECT_VERSION` for an upload.
- `just testflight-build` stops after producing an IPA in `build/testflight/export/`.

## Status

Inspect is actively maintained in its rewritten SwiftUI/SPM form. If you are looking at older screenshots, implementation notes, or legacy code references, they likely predate this rewrite.
