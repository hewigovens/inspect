# Inspect

Inspect is a modern iOS TLS inspection app built with SwiftUI, Swift Package Manager, and XcodeGen. It inspects a live HTTPS connection, captures the evaluated trust chain, and renders decoded certificate details without the legacy OpenSSL/UIKit stack.

## What It Does

- Inspect a pasted HTTPS URL or a target shared from Safari.
- Decode the full presented certificate chain.
- Show parsed X.509 details including SANs, key usages, EKUs, AIA, SKI/AKI, and certificate policies.
- Export DER certificates from the chain.
- Surface security signals for trust failures, hostname mismatch, weak crypto, suspicious leaf CA usage, and common TLS interception products.

## Project Layout

- `App/`: SwiftUI iOS application target.
- `Extension/`: Safari action/share extension entry point.
- `Packages/InspectCore/`: local Swift package with `Core` and `Feature` sources.
- `project.yml`: XcodeGen source of truth for the Xcode project.

## Development

Generate the project:

```bash
xcodegen generate
```

Run package tests:

```bash
cd Packages/InspectCore
swift test
```

Build the iOS app:

```bash
xcodebuild -scheme Inspect -project Inspect.xcodeproj -destination 'generic/platform=iOS Simulator' build
```
