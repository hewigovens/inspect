set shell := ["zsh", "-eu", "-o", "pipefail", "-c"]

default:
    @just --list

generate:
    xcodegen generate

rust-core-check:
    cargo check --manifest-path Rust/inspect-tunnel-core/Cargo.toml

rust-core-test:
    cargo test --manifest-path Rust/inspect-tunnel-core/Cargo.toml

rust-core-build:
    cargo build --manifest-path Rust/inspect-tunnel-core/Cargo.toml

rust-core-replay fixture="Rust/inspect-tunnel-core/fixtures/replay/sample_sni.json":
    cargo run --manifest-path Rust/inspect-tunnel-core/Cargo.toml --bin inspect-tunnel-replay -- {{fixture}} --pretty

rust-core-integration:
    cargo test --manifest-path Rust/inspect-tunnel-core/Cargo.toml -- --nocapture

rust-core-tun2proxy-harness:
    cargo test --manifest-path Rust/inspect-tunnel-core/Cargo.toml tun2proxy_run_forwards_tcp_and_emits_tls_observations -- --nocapture

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
