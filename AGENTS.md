# Inspect Agent Notes

- [CONTRIBUTING.md](CONTRIBUTING.md) is the guide for setup, architecture, commands, signing, releases, and screenshots. Keep detailed workflows there rather than duplicating them here.
- `project.yml` is the source of truth for the Xcode project. Regenerate with `just generate`, which includes the ignored `project.local.yml` when present. Never commit the generated project, local signing settings, `.env`, or build outputs.
- Use [justfile](justfile) for common tasks and `xcodebuild ... | xcbeautify` for build output.
- Compile with Xcode 27.1 or newer. Preserve the iOS 18 and macOS 15 deployment targets and availability guards around newer APIs.

## Verification and Releases

- Run focused shared tests with `swift test --package-path Packages/InspectCore`; use the platform build/test recipes for affected app behavior. Documentation changes need diff, link, and command checks rather than app rebuilds.
- Upload builds through [scripts/testflight.sh](scripts/testflight.sh), which reads `.env`. Run iOS and macOS uploads sequentially because they share archive/export paths. Check the chosen build number against the selected platform before re-uploading.
- Both platforms share their version settings in `project.yml`. Verify signed exports and App Store Connect processing state; a `VALID` upload is separate from an App Review submission.
- Before submitting, validate the exact platform, version, build, listing metadata, review details, and screenshots. Preserve the existing release policy and verify the resulting review state.
- Capture storefront images with [scripts/app_store_screenshots.sh](scripts/app_store_screenshots.sh) and the built-in `INSPECT_SCREENSHOT_SCENARIO` mode. Check the rendered content as well as dimensions, and verify uploaded assets reach `COMPLETE`.

## Code Style

- Only add comments where the logic isn't self-evident. Most code should speak for itself. Avoid restating what a function or variable name already conveys.
- Do not add comments to code you didn't change.

## Architecture

- Avoid vague file names like `*Support.swift`. Prefer focused names that describe the actual responsibility, such as `Theme`, `Layout`, `Navigation`, `Rows`, `Sections`, `Metadata`, or `WindowLayout`.
- Split mixed SwiftUI files by responsibility instead of keeping large “components” buckets. Prefer separate files for shell views, sections, rows, and platform-specific presentations.
- Reuse shared primitives before adding app-local duplicates. Current shared examples include `InspectSection`, `InspectIconTile`, `InspectionAppMetadata`, `InspectAppLinks`, and the unified settings components in `InspectSettingsComponents.swift`.
- When macOS and iOS share the same app-level concept, prefer one shared model in `InspectKit` rather than parallel enums or duplicated constants in each app target. Settings rows, diagnostics/about sections, and error normalization are already unified in InspectKit.
- Consolidate conditional compilation in one place when possible. `Layout.swift` uses a single `PlatformValues` struct; prefer that pattern over scattering `#if os(...)` branches through feature views.
- Keep Live Monitor coordination app-scoped so closing one window does not disable tunnel control in another.
- Classify certificate revocation failures using Security error codes and preserve diagnostics for other trust-evaluation failures.

### MVVM + Protocol-Oriented Views

- Views should not take closures for user actions. Define a protocol (e.g. `InspectionRecentActions`) that declares the actions a view needs, then pass the conforming object as `actions:`.
- Compose action protocols when a parent view aggregates children: `protocol InspectionResultsActions: InspectionChainActions, InspectionRecentActions {}`.
- The parent view (e.g. `InspectionRootView`) conforms to the composed protocol via an extension, keeping action implementations out of the view body.
- Name action protocols `*Actions` (not `*Delegate`) to avoid triggering the `class_delegate_protocol` lint rule — these are used by value-type views.
- Keep UI text concise. Prefer short labels (“Not checked”, “Checking…”) over verbose descriptions.

## InspectKit Feature Directory Structure

The `Packages/InspectCore/Sources/Feature/` directory is organized into subdirectories by domain:

- `Certificate/` — Certificate detail views, chain views, export, row components
- `Monitor/` — Live monitor views, store, host classification, tunnel log, NEVPNStatus extension
- `Inspection/` — Root inspection view, input card, results, recent items, screenshots
- `Diagnostics/` — Diagnostics cards, container, events/tunnel log views
- `Settings/` — Shared settings components (rows, sections), review requester, error normalizer
- `Theme/` — Colors, typography, glyphs, surfaces, layout constants, view modifiers
- `Shared/` — Strings, app links, routes, clipboard, platform support, section enum

Place new files in the appropriate subdirectory rather than at the Feature root.
