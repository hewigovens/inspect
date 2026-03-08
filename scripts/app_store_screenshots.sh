#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
source "$script_dir/lib/common.sh"

env_file="${APP_STORE_SCREENSHOTS_ENV_FILE:-$repo_root/.env}"
derived_data_path="$repo_root/build/app-store-screenshots/DerivedData"
output_root="$repo_root/build/app-store-screenshots/output"
iphone_output_path="$output_root/iphone"
ipad_output_path="$output_root/ipad"
project_path="$repo_root/Inspect.xcodeproj"
bundle_id="in.fourplex.Inspect"
ios_runtime="com.apple.CoreSimulator.SimRuntime.iOS-26-2"
iphone_device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-13-Pro-Max"
ipad_device_type="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-6th-generation-8GB"
iphone_simulator_name="Inspect App Store iPhone 6.5"
ipad_simulator_name="Inspect App Store iPad"
app_path=""

configure() {
  require_command asc
  require_command python3
  require_command xcbeautify
  require_command xcodebuild
  require_command xcodegen
  require_command xcrun

  mkdir -p "$iphone_output_path" "$ipad_output_path"
}

simulator_udid() {
  local simulator_name="$1"

  xcrun simctl list devices --json | python3 -c '
import json
import sys

name = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
for runtimes in devices.values():
    for device in runtimes:
        if device["name"] == name:
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
' "$simulator_name"
}

ensure_simulator() {
  local simulator_name="$1"
  local device_type="$2"
  local udid

  if udid="$(simulator_udid "$simulator_name" 2>/dev/null)"; then
    printf '%s\n' "$udid"
    return 0
  fi

  xcrun simctl create "$simulator_name" "$device_type" "$ios_runtime"
}

boot_simulator() {
  local udid="$1"

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl status_bar "$udid" override \
    --time 9:41 \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100
}

clear_simulator() {
  local udid="$1"

  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$app_path"
}

build_app() {
  generate_xcode_project "$repo_root"

  rm -rf "$derived_data_path" "$output_root"
  mkdir -p "$iphone_output_path" "$ipad_output_path"

  log "Building Inspect for Simulator"
  run_xcodebuild \
    -scheme Inspect \
    -project "$project_path" \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$derived_data_path" \
    build

  app_path="$derived_data_path/Build/Products/Debug-iphonesimulator/Inspect.app"
  if [[ ! -d "$app_path" ]]; then
    fail "Built app not found at $app_path"
  fi
}

capture_scenario() {
  local udid="$1"
  local scenario="$2"
  local output_path="$3"
  local wait_seconds="$4"

  clear_simulator "$udid"

  SIMCTL_CHILD_INSPECT_SCREENSHOT_SCENARIO="$scenario" \
    xcrun simctl launch --terminate-running-process "$udid" "$bundle_id" >/dev/null

  sleep "$wait_seconds"
  xcrun simctl io "$udid" screenshot "$output_path" >/dev/null
}

capture_device_set() {
  local udid="$1"
  local output_path="$2"

  capture_scenario "$udid" inspect-tab "$output_path/01-inspect-tab.png" 2
  capture_scenario "$udid" monitor-tab "$output_path/02-live-monitor.png" 2
  capture_scenario "$udid" host-detail "$output_path/03-host-detail.png" 2
  capture_scenario "$udid" certificate-chain "$output_path/04-cert-chain.png" 2
}

upload_screenshots() {
  local localization_id="$1"

  [[ -n "$localization_id" ]] || fail "Version localization ID is required for upload"

  log "Uploading iPhone screenshots"
  run_asc screenshots upload \
    --version-localization "$localization_id" \
    --path "$iphone_output_path" \
    --device-type IPHONE_65

  log "Uploading iPad screenshots"
  run_asc screenshots upload \
    --version-localization "$localization_id" \
    --path "$ipad_output_path" \
    --device-type IPAD_PRO_3GEN_129
}

usage() {
  printf '%s\n' "Usage: scripts/app_store_screenshots.sh [capture|upload VERSION_LOCALIZATION_ID|capture-upload VERSION_LOCALIZATION_ID]" >&2
}

load_env_file "$env_file"
normalize_auth_env
build_asc_args
configure

iphone_udid="$(ensure_simulator "$iphone_simulator_name" "$iphone_device_type")"
ipad_udid="$(ensure_simulator "$ipad_simulator_name" "$ipad_device_type")"

case "${1:-capture}" in
  capture)
    build_app
    boot_simulator "$iphone_udid"
    boot_simulator "$ipad_udid"
    capture_device_set "$iphone_udid" "$iphone_output_path"
    capture_device_set "$ipad_udid" "$ipad_output_path"
    ;;
  upload)
    upload_screenshots "${2:-}"
    ;;
  capture-upload)
    build_app
    boot_simulator "$iphone_udid"
    boot_simulator "$ipad_udid"
    capture_device_set "$iphone_udid" "$iphone_output_path"
    capture_device_set "$ipad_udid" "$ipad_output_path"
    upload_screenshots "${2:-}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
