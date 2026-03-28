# Inspect Agent Notes

- `project.yml` is the source of truth for the Xcode project. Regenerate `Inspect.xcodeproj` with `xcodegen generate`; do not commit the generated project.
- Use [`justfile`](/Users/hewig/workspace/h/Inspect/justfile) for common local tasks.
- Prefer `xcbeautify` for `xcodebuild` output. The repo scripts and CI are expected to use `xcodebuild ... | xcbeautify`.
- TestFlight uploads go through [`scripts/testflight.sh`](/Users/hewig/workspace/h/Inspect/scripts/testflight.sh) and read settings from `.env`.
- App Store screenshots go through [`scripts/app_store_screenshots.sh`](/Users/hewig/workspace/h/Inspect/scripts/app_store_screenshots.sh). Use the built-in `INSPECT_SCREENSHOT_SCENARIO` launch mode rather than hand-editing UI state for storefront captures.
- Required TestFlight env vars: `ASC_APP_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_PATH`.
- If the current App Store Connect app already has the repo's `CURRENT_PROJECT_VERSION`, set `TESTFLIGHT_BUILD_NUMBER` in `.env` before uploading.

## Release Pipeline

iOS and macOS share the same `MARKETING_VERSION` in `project.yml` but need separate `CURRENT_PROJECT_VERSION` (build numbers) because App Store Connect requires unique build numbers per platform upload.

**iOS TestFlight:**
```
just testflight
```

**macOS TestFlight:**
```
TESTFLIGHT_SCHEME=InspectMac TESTFLIGHT_DESTINATION="generic/platform=macOS" just testflight
```

**Both platforms (sequential):**
```
just testflight
TESTFLIGHT_SCHEME=InspectMac TESTFLIGHT_DESTINATION="generic/platform=macOS" TESTFLIGHT_BUILD_NUMBER=<next> just testflight
```

The script auto-detects `.ipa` (iOS) vs `.pkg` (macOS) and uses the correct `asc` upload flag (`--ipa` vs `--pkg`). macOS builds require a separate build number if the same number was already uploaded for iOS.

After upgrading Xcode, run "Download Manual Profiles" in Xcode > Settings > Accounts before building, otherwise the iOS export will fail with a missing `embedded.mobileprovision` error.

## Code Style

- Only add comments where the logic isn't self-evident. Most code should speak for itself. Avoid restating what a function or variable name already conveys.
- Do not add comments to code you didn't change.

## Architecture

- Avoid vague file names like `*Support.swift`. Prefer focused names that describe the actual responsibility, such as `Theme`, `Layout`, `Navigation`, `Rows`, `Sections`, `Metadata`, or `WindowLayout`.
- Split mixed SwiftUI files by responsibility instead of keeping large “components” buckets. Prefer separate files for shell views, sections, rows, and platform-specific presentations.
- Reuse shared primitives before adding app-local duplicates. Current shared examples include `InspectSection`, `InspectIconTile`, `InspectionAppMetadata`, `InspectAppLinks`, and the unified settings components in `InspectSettingsComponents.swift`.
- When macOS and iOS share the same app-level concept, prefer one shared model in `InspectKit` rather than parallel enums or duplicated constants in each app target. Settings rows, diagnostics/about sections, and error normalization are already unified in InspectKit.
- Consolidate conditional compilation in one place when possible. `Layout.swift` uses a single `PlatformValues` struct; prefer that pattern over scattering `#if os(...)` branches through feature views.

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
