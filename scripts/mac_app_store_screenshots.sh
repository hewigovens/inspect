#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
source "$script_dir/lib/common.sh"

env_file="${APP_STORE_SCREENSHOTS_ENV_FILE:-$repo_root/.env}"
derived_data_path="$repo_root/build/app-store-screenshots-mac/DerivedData"
output_root="$repo_root/build/app-store-screenshots-mac/output"
mac_output_path="$output_root/mac"
project_path="$repo_root/Inspect.xcodeproj"
bundle_id="in.fourplex.Inspect"
app_path=""
app_pid=""
app_log_path=""

configure() {
  require_command asc
  require_command python3
  require_command xcbeautify
  require_command xcodebuild
  require_command xcodegen
  require_command sips

  mkdir -p "$mac_output_path"
}

build_app() {
  generate_xcode_project "$repo_root"

  rm -rf "$derived_data_path" "$output_root"
  mkdir -p "$mac_output_path"

  log "Building InspectMac for screenshots"
  run_xcodebuild \
    -scheme InspectMac \
    -project "$project_path" \
    -configuration Debug \
    -destination "platform=macOS" \
    -derivedDataPath "$derived_data_path" \
    build

  app_path="$derived_data_path/Build/Products/Debug/Inspect.app"
  if [[ ! -d "$app_path" ]]; then
    fail "Built app not found at $app_path"
  fi
}

quit_app() {
  osascript -e 'tell application id "'"$bundle_id"'" to quit' >/dev/null 2>&1 || true
  launchctl unsetenv INSPECT_SCREENSHOT_SCENARIO >/dev/null 2>&1 || true
  launchctl unsetenv INSPECT_MAC_SCREENSHOT_OUTPUT_PATH >/dev/null 2>&1 || true
  if [[ -n "${app_pid:-}" ]]; then
    kill "$app_pid" >/dev/null 2>&1 || true
    sleep 0.5
    if kill -0 "$app_pid" >/dev/null 2>&1; then
      kill -9 "$app_pid" >/dev/null 2>&1 || true
    fi
    wait "$app_pid" >/dev/null 2>&1 || true
    app_pid=""
  fi
  app_log_path=""
  sleep 1
}

wait_for_output() {
  local destination_path="$1"
  local attempts=0

  while [[ "$attempts" -lt 80 ]]; do
    if [[ -n "$app_log_path" && -f "$app_log_path" ]]; then
      local decoded
      decoded="$(
        python3 - "$app_log_path" "$destination_path" <<'PY'
import base64
import sys

log_path, destination_path = sys.argv[1], sys.argv[2]
try:
    with open(log_path, "r", encoding="utf-8") as handle:
        for line in handle:
            if not line.startswith("SCREENSHOT_BASE64 "):
                continue
            payload = line[len("SCREENSHOT_BASE64 "):].strip()
            try:
                decoded = base64.b64decode(payload)
            except Exception:
                raise SystemExit(0)
            with open(destination_path, "wb") as output:
                output.write(decoded)
            print(destination_path)
            raise SystemExit(0)
except FileNotFoundError:
    raise SystemExit(0)
PY
      )"

      if [[ -n "$decoded" && -f "$decoded" ]]; then
        printf '%s\n' "$decoded"
        return 0
      fi
    fi

    attempts=$((attempts + 1))
    sleep 0.25
  done

  if [[ -n "$app_log_path" && -f "$app_log_path" ]]; then
    cat "$app_log_path" >&2
  fi

  fail "Timed out waiting for screenshot export"
}

launch_scenario() {
  local scenario="$1"
  local requested_path="$2"

  quit_app

  log "Launching mac screenshot scenario: $scenario"
  app_log_path="$output_root/${scenario}.log"
  rm -f "$app_log_path"
  INSPECT_SCREENSHOT_SCENARIO="$scenario" \
    INSPECT_MAC_SCREENSHOT_OUTPUT_PATH="$requested_path" \
    INSPECT_MAC_SCREENSHOT_STDOUT=1 \
    "$app_path/Contents/MacOS/Inspect" >"$app_log_path" 2>&1 &
  app_pid=$!
}

capture_scenario() {
  local scenario="$1"
  local filename="$2"
  local path="$mac_output_path/$filename"
  local decoded_path

  rm -f "$path"
  launch_scenario "$scenario" "$path"
  decoded_path="$(wait_for_output "$path")"
  quit_app
  [[ -n "$decoded_path" && -f "$decoded_path" ]] || fail "Expected screenshot not found for $scenario"
}

validate_screenshots() {
  local failed=0

  for path in "$mac_output_path"/*.png; do
    [[ -f "$path" ]] || continue

    local width height
    width="$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')"

    case "${width}x${height}" in
      1280x800|1440x900|2560x1600|2880x1800)
        ;;
      *)
        log "Unexpected mac screenshot size for $(basename "$path"): ${width}x${height}"
        failed=1
        ;;
    esac
  done

  [[ "$failed" -eq 0 ]] || fail "One or more mac screenshots do not match APP_DESKTOP dimensions"
}

clear_existing_screenshots() {
  local localization_id="$1"

  local ids
  ids="$(
    run_asc screenshots list --version-localization "$localization_id" --output json | python3 - <<'PY'
import json
import sys

payload = json.load(sys.stdin)
for item in payload.get("data", []) or []:
    if item.get("attributes", {}).get("displayType") == "APP_DESKTOP":
        print(item["id"])
PY
  )"

  if [[ -z "$ids" ]]; then
    return 0
  fi

  log "Removing existing mac screenshots"
  while IFS= read -r screenshot_id; do
    [[ -n "$screenshot_id" ]] || continue
    run_asc screenshots delete --id "$screenshot_id" --confirm >/dev/null
  done <<< "$ids"
}

upload_screenshots() {
  local localization_id="$1"

  [[ -n "$localization_id" ]] || fail "Version localization ID is required for upload"

  clear_existing_screenshots "$localization_id"

  log "Uploading mac screenshots"
  run_asc screenshots upload \
    --version-localization "$localization_id" \
    --path "$mac_output_path" \
    --device-type APP_DESKTOP
}

usage() {
  printf '%s\n' "Usage: scripts/mac_app_store_screenshots.sh [capture|upload VERSION_LOCALIZATION_ID|capture-upload VERSION_LOCALIZATION_ID]" >&2
}

trap quit_app EXIT

load_env_file "$env_file"
normalize_auth_env
build_asc_args
configure

case "${1:-capture}" in
  capture)
    build_app
    capture_scenario inspect-tab 01-inspect-tab.png
    capture_scenario monitor-tab 02-monitor-tab.png
    capture_scenario host-detail 03-host-detail.png
    capture_scenario certificate-chain 04-certificate-chain.png
    validate_screenshots
    ;;
  upload)
    upload_screenshots "${2:-}"
    ;;
  capture-upload)
    build_app
    capture_scenario inspect-tab 01-inspect-tab.png
    capture_scenario monitor-tab 02-monitor-tab.png
    capture_scenario host-detail 03-host-detail.png
    capture_scenario certificate-chain 04-certificate-chain.png
    validate_screenshots
    upload_screenshots "${2:-}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
