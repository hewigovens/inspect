# Inspect Agent Notes

- `project.yml` is the source of truth for the Xcode project. Regenerate `Inspect.xcodeproj` with `xcodegen generate`; do not commit the generated project.
- Use [`justfile`](/Users/hewig/workspace/h/Inspect/justfile) for common local tasks. The main release entry point is `just testflight`.
- Prefer `xcbeautify` for `xcodebuild` output. The repo scripts and CI are expected to use `xcodebuild ... | xcbeautify`.
- TestFlight uploads go through [`scripts/testflight.sh`](/Users/hewig/workspace/h/Inspect/scripts/testflight.sh) and read settings from `.env`.
- Required TestFlight env vars: `ASC_APP_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_PATH`.
- If the current App Store Connect app already has the repo's `CURRENT_PROJECT_VERSION`, set `TESTFLIGHT_BUILD_NUMBER` in `.env` before uploading.
