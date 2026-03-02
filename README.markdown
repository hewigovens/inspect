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

## Status

Inspect is actively maintained in its rewritten SwiftUI/SPM form. If you are looking at older screenshots, implementation notes, or legacy code references, they likely predate this rewrite.
