# Inspect Agent Notes

- `project.yml` is the source of truth for the Xcode project. Regenerate `Inspect.xcodeproj` with `xcodegen generate`; do not commit the generated project.
- Use [`justfile`](/Users/hewig/workspace/h/Inspect/justfile) for common local tasks. The main release entry point is `just testflight`.
- Prefer `xcbeautify` for `xcodebuild` output. The repo scripts and CI are expected to use `xcodebuild ... | xcbeautify`.
- TestFlight uploads go through [`scripts/testflight.sh`](/Users/hewig/workspace/h/Inspect/scripts/testflight.sh) and read settings from `.env`.
- App Store screenshots go through [`scripts/app_store_screenshots.sh`](/Users/hewig/workspace/h/Inspect/scripts/app_store_screenshots.sh). Use the built-in `INSPECT_SCREENSHOT_SCENARIO` launch mode rather than hand-editing UI state for storefront captures.
- Required TestFlight env vars: `ASC_APP_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_PATH`.
- If the current App Store Connect app already has the repo's `CURRENT_PROJECT_VERSION`, set `TESTFLIGHT_BUILD_NUMBER` in `.env` before uploading.

## Architecture

- Avoid vague file names like `*Support.swift`. Prefer focused names that describe the actual responsibility, such as `Theme`, `Layout`, `Navigation`, `Rows`, `Sections`, `Metadata`, or `WindowLayout`.
- Split mixed SwiftUI files by responsibility instead of keeping large “components” buckets. Prefer separate files for shell views, sections, rows, and platform-specific presentations.
- Reuse shared primitives before adding app-local duplicates. Current shared examples include `InspectSection`, `InspectIconTile`, `InspectionAppMetadata`, and `InspectAppLinks`.
- When macOS and iOS share the same app-level concept, prefer one shared model in `InspectKit` rather than parallel enums or duplicated constants in each app target.
- Consolidate conditional compilation in one place when possible. Prefer platform-specific files or shared `Layout`/`Theme` helpers over scattering `#if os(...)` branches through feature views.
