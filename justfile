set shell := ["zsh", "-eu", "-o", "pipefail", "-c"]
mod rust

default:
    @just --list --list-submodules

generate:
    xcodegen generate

test-ios-sim device_id="863DCA4D-25BC-4E56-B6DA-D94FEC42A174":
    xcodegen generate
    xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination "platform=iOS Simulator,id={{device_id}}" test | xcbeautify

build-macos:
    xcodegen generate
    xcodebuild -project Inspect.xcodeproj -scheme InspectMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build | xcbeautify

test-macos:
    xcodegen generate
    xcodebuild -project Inspect.xcodeproj -scheme InspectMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test | xcbeautify

smoke-macos-tunnel url="https://example.com" derived_data="target/DerivedData/InspectMacSmoke":
    #!/usr/bin/env bash
    set -euo pipefail
    DERIVED_DATA="{{derived_data}}"
    URL="{{url}}"
    APP_INSTALL_PATH="/Applications/Inspect Smoke.app"
    xcodegen generate
    xcodebuild -project Inspect.xcodeproj -scheme InspectMac -destination 'platform=macOS' -derivedDataPath "$DERIVED_DATA" build | xcbeautify
    APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/Inspect.app"
    if [[ ! -d "$APP_BUNDLE" ]]; then
        echo "Built app bundle not found at $APP_BUNDLE" >&2
        exit 1
    fi
    rm -rf "$APP_INSTALL_PATH"
    ditto "$APP_BUNDLE" "$APP_INSTALL_PATH"
    open -W -n "$APP_INSTALL_PATH" --args --smoke-test --smoke-test-url "$URL"

testflight:
    ./scripts/testflight.sh upload

testflight-build:
    ./scripts/testflight.sh build

testflight-dry-run:
    ./scripts/testflight.sh dry-run

app-store-screenshots:
    ./scripts/app_store_screenshots.sh capture

run-ios-device log_file="target/ios-device-console.log" tunnel_log_file="target/ios-device-tunnel.log" app_group="group.in.fourplex.inspect.monitor":
    #!/usr/bin/env bash
    set -euo pipefail
    LOG_FILE="{{log_file}}"
    TUNNEL_LOG_FILE="{{tunnel_log_file}}"
    APP_GROUP="{{app_group}}"
    xcodegen generate
    if [[ -z "${DEVICE_ID:-}" ]]; then
        DEVICE_ID="$(
            xcrun xctrace list devices 2>/dev/null \
            | awk '/iPhone/ && $0 !~ /Simulator/ { print }' \
            | sed -E 's/.*\(([0-9A-Fa-f-]+)\)[[:space:]]*$/\1/' \
            | head -n 1
        )"
        if [[ -z "$DEVICE_ID" ]]; then
            echo "No connected iPhone device found. Set DEVICE_ID if needed." >&2
            exit 1
        fi
    fi
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$TUNNEL_LOG_FILE")"
    fetch_tunnel_log() {
        rm -f "$TUNNEL_LOG_FILE"
        if xcrun devicectl device copy from \
            --device "$DEVICE_ID" \
            --domain-type appGroupDataContainer \
            --domain-identifier "$APP_GROUP" \
            --source tunnel.log \
            --destination "$TUNNEL_LOG_FILE" \
            >/dev/null 2>&1; then
            echo "Copied tunnel log to $TUNNEL_LOG_FILE"
        else
            echo "Failed to copy tunnel log from app group $APP_GROUP" >&2
        fi
    }
    trap fetch_tunnel_log EXIT
    xcodebuild -project Inspect.xcodeproj -scheme Inspect -destination "id=$DEVICE_ID" -allowProvisioningUpdates -derivedDataPath target/DerivedData/InspectDevice build | xcbeautify
    APP_PATH="target/DerivedData/InspectDevice/Build/Products/Debug-iphoneos/Inspect.app"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Built app not found at $APP_PATH" >&2
        exit 1
    fi
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
    echo "Streaming iOS app console logs to $LOG_FILE (Ctrl+C to stop)..."
    echo "Shared tunnel log will be copied to $TUNNEL_LOG_FILE on exit."
    xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing --console in.fourplex.Inspect 2>&1 | tee "$LOG_FILE"
