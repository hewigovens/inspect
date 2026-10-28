#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
source "$script_dir/lib/common.sh"

env_file="${APP_STORE_SCREENSHOTS_ENV_FILE:-$repo_root/.env}"
derived_data_path="$repo_root/build/app-store-screenshots/DerivedData"
output_root="$repo_root/build/app-store-screenshots/output"
project_path="$repo_root/Inspect.xcodeproj"
bundle_id="in.fourplex.Inspect"

duo_outer_output_path="$output_root/duo-outer"
duo_inner_output_path="$output_root/duo-inner"
screenshot_wait_seconds="${APP_STORE_SCREENSHOTS_WAIT_SECONDS:-2}"
app_path=""

configure() {
  require_command asc
  require_command python3
  require_command xcbeautify
  require_command xcodebuild
  require_command xcodegen
  require_command xcrun

  ensure_output_directories
}

# macOS ships bash 3.2, which has no associative arrays, so this stays a case.
describe_set() {
  case "$1" in
    iphone)
      SET_OUTPUT="$output_root/iphone"
      SET_SIMULATOR="Inspect App Store iPhone 6.5"
      SET_DISPLAY_TYPE="IPHONE_65"
      SET_DEVICE_TYPES="com.apple.CoreSimulator.SimDeviceType.iPhone-13-Pro-Max"
      ;;
    ipad)
      SET_OUTPUT="$output_root/ipad"
      SET_SIMULATOR="Inspect App Store iPad"
      SET_DISPLAY_TYPE="IPAD_PRO_3GEN_129"
      # Space separated, in preference order: the first that a runtime accepts wins.
      SET_DEVICE_TYPES="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-6th-generation-8GB com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-6th-generation-16GB com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-5th-generation"
      ;;
    duo)
      SET_OUTPUT="$duo_outer_output_path"
      SET_SIMULATOR="Inspect App Store iPhone Duo"
      SET_DISPLAY_TYPE="APP_IPHONE_DUO"
      SET_DEVICE_TYPES="com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
      ;;
    *)
      fail "Unknown screenshot set: $1"
      ;;
  esac
}

# No single runtime covers every device type: iOS 27.1 only runs iPhone Duo,
# while iOS 27.0 runs the 6.5" iPhone and iPad sets.
runtime_for_device_type() {
  local device_type="$1"
  local runtime

  while IFS= read -r runtime; do
    [[ -n "$runtime" ]] || continue
    if xcrun simctl create "Inspect-runtime-probe" "$device_type" "$runtime" >/dev/null 2>&1; then
      xcrun simctl delete Inspect-runtime-probe >/dev/null 2>&1
      printf '%s\n' "$runtime"
      return 0
    fi
  done < <(available_ios_runtimes_newest_first)

  return 1
}

available_ios_runtimes_newest_first() {
  xcrun simctl list runtimes --json | python3 -c '
import json
import sys

candidates = []

for runtime in json.load(sys.stdin)["runtimes"]:
    if runtime.get("platform") != "iOS":
        continue
    if runtime.get("available") is False:
        continue

    identifier = runtime.get("identifier", "")
    version = runtime.get("version", "")
    if "SimRuntime" not in identifier or not version:
        continue

    parts = version.split(".")
    try:
        major, minor = int(parts[0]), int(parts[1].split("-")[0])
    except (IndexError, ValueError):
        continue

    candidates.append((major, minor, identifier))

for _, _, identifier in sorted(candidates, reverse=True):
    print(identifier)
'
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
  local runtime

  if udid="$(simulator_udid "$simulator_name" 2>/dev/null)"; then
    printf '%s\n' "$udid"
    return 0
  fi

  # Device type and runtime only pair up for some combinations.
  runtime="$(runtime_for_device_type "$device_type")" || return 1
  xcrun simctl create "$simulator_name" "$device_type" "$runtime"
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

  # Inner captures need a manual unfold, so they are never discarded here.
  rm -rf "$derived_data_path"
  ensure_output_directories

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

  # Only the display being captured is cleared; inner capture needs a manual unfold.
  local set
  for set in "${SETS[@]}"; do
    if [[ "$set" != duo ]]; then
      describe_set "$set"
      rm -f "$SET_OUTPUT"/*.png
      continue
    fi

    case "$duo_display" in
      outer) rm -f "$duo_outer_output_path"/*.png ;;
      inner) rm -f "$duo_inner_output_path"/*.png ;;
      both) rm -f "$duo_outer_output_path"/*.png "$duo_inner_output_path"/*.png ;;
    esac
  done
}

ensure_output_directories() {
  local set

  for set in iphone ipad duo; do
    describe_set "$set"
    mkdir -p "$SET_OUTPUT"
  done
  mkdir -p "$duo_inner_output_path"
}

# The inactive display captures as a uniform frame, which is why this samples content.
is_blank_capture() {
  local path="$1"
  local tiny

  tiny="$(mktemp -t inspect-screenshot).png"
  sips -Z 48 --out "$tiny" "$path" >/dev/null 2>&1 || {
    rm -f "$tiny"
    return 1
  }

  python3 - "$tiny" <<'PY'
import struct
import sys
import zlib

data = open(sys.argv[1], "rb").read()
pos, idat = 8, b""
width = height = bit_depth = color_type = 0

while pos < len(data):
    length = struct.unpack(">I", data[pos:pos + 4])[0]
    name = data[pos + 4:pos + 8]
    chunk = data[pos + 8:pos + 8 + length]
    if name == b"IHDR":
        width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
    elif name == b"IDAT":
        idat += chunk
    pos += 12 + length

raw = zlib.decompress(idat)
channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
pixel_bytes = max(1, channels * (bit_depth // 8))
stride = width * pixel_bytes

colors = set()
for row in range(height):
    start = row * stride
    for offset in range(0, stride, pixel_bytes * 3 or 1):
        colors.add(bytes(raw[start + offset:start + offset + pixel_bytes]))

raise SystemExit(0 if len(colors) <= 12 else 1)
PY
  local blank=$?
  rm -f "$tiny"

  return "$blank"
}

capture_scenario() {
  local udid="$1"
  local scenario="$2"
  local output_path="$3"
  local display="${4:-primary}"

  clear_simulator "$udid"

  SIMCTL_CHILD_INSPECT_SCREENSHOT_SCENARIO="$scenario" \
    xcrun simctl launch --terminate-running-process "$udid" "$bundle_id" >/dev/null

  sleep "$screenshot_wait_seconds"
  xcrun simctl io "$udid" screenshot --display "$display" "$output_path" >/dev/null 2>&1
}

capture_device_set() {
  local udid="$1"
  local output_path="$2"
  local display="${3:-primary}"

  capture_scenario "$udid" inspect-tab "$output_path/01-inspect-tab.png" "$display"
  capture_scenario "$udid" monitor-tab "$output_path/02-live-monitor.png" "$display"
  capture_scenario "$udid" host-detail "$output_path/03-host-detail.png" "$display"
  capture_scenario "$udid" certificate-chain "$output_path/04-cert-chain.png" "$display"
}

capture_duo_outer_set() {
  local udid="$1"
  local output_path="$2"

  capture_device_set "$udid" "$output_path" primary
  verify_duo_captures "$output_path" "outer" "fold (close) the device"
}

capture_duo_inner_set() {
  local udid="$1"
  local output_path="$2"

  capture_device_set "$udid" "$output_path" primary-1
  verify_duo_captures "$output_path" "inner" "unfold (open) the device"
}

verify_duo_captures() {
  local output_path="$1"
  local label="$2"
  local instruction="$3"
  local file

  for file in "$output_path"/*.png; do
    if is_blank_capture "$file"; then
      rm -f "$output_path"/*.png
      fail "iPhone Duo $label-display capture is blank. Please $instruction in Device Hub (Xcode 27.1 > Open Developer Tool > Device Hub > "Inspect App Store iPhone Duo") and rerun."
    fi
  done
}

# asc appends on upload, so repeated runs would stack duplicates.
# SCREENSHOTS_UPLOAD_APPEND=1 opts back into appending.
upload_screenshot_set() {
  local localization_id="$1"
  local label="$2"
  local path="$3"
  local device_type="$4"
  local -a args=()

  if is_truthy "${SCREENSHOTS_UPLOAD_APPEND:-}"; then
    log "Uploading $label screenshots (append)"
  else
    log "Uploading $label screenshots (replacing existing set)"
    args=(--replace --confirm)
  fi

  run_asc screenshots upload \
    --version-localization "$localization_id" \
    --path "$path" \
    --device-type "$device_type" \
    "${args[@]:-}"
}

upload_screenshots() {
  local localization_id="$1"

  [[ -n "$localization_id" ]] || fail "Version localization ID is required for upload"
  [[ ${#SETS[@]} -gt 0 ]] || fail "No screenshot sets selected"

  local set
  for set in "${SETS[@]}"; do
    if [[ "$set" == duo ]]; then
      upload_duo_screenshots "$localization_id"
    else
      describe_set "$set"
      upload_screenshot_set "$localization_id" "$set" "$SET_OUTPUT" "$SET_DISPLAY_TYPE"
    fi
  done
}

# One set per display type, so both Duo directories merge. Inner first: they
# show the split layouts.
upload_duo_screenshots() {
  local localization_id="$1"
  local staging
  local file
  local index=1

  if ! compgen -G "$duo_inner_output_path/*.png" >/dev/null &&
    ! compgen -G "$duo_outer_output_path/*.png" >/dev/null
  then
    log "Skipping iPhone Duo upload; no screenshots captured"
    return 0
  fi

  staging="$(mktemp -d)/duo"
  mkdir -p "$staging"

  for file in "$duo_inner_output_path"/*.png "$duo_outer_output_path"/*.png; do
    [[ -f "$file" ]] || continue
    cp "$file" "$staging/$(printf '%02d' "$index").png"
    index=$((index + 1))
  done

  upload_screenshot_set "$localization_id" "iPhone Duo" "$staging" APP_IPHONE_DUO
}

capture_all() {
  local set
  local udid
  local output

  for set in "${SETS[@]}"; do
    describe_set "$set"
    udid="$(udid_for "$set")"
    output="$SET_OUTPUT"
    boot_simulator "$udid"

    if [[ "$set" == duo ]]; then
      capture_duo "$udid"
    else
      capture_device_set "$udid" "$output"
    fi
  done
}

# The two displays need opposite poses, so "both" must pause for the unfold.
capture_duo() {
  local udid="$1"

  case "$duo_display" in
    outer)
      capture_duo_outer_set "$udid" "$duo_outer_output_path"
      ;;
    inner)
      capture_duo_inner_set "$udid" "$duo_inner_output_path"
      ;;
    both)
      capture_duo_outer_set "$udid" "$duo_outer_output_path"
      await_duo_posture "unfold"
      capture_duo_inner_set "$udid" "$duo_inner_output_path"
      ;;
  esac
}

await_duo_posture() {
  local action="$1"

  log ""
  log "Unfold the device in Device Hub, then press Return to capture the inner display."
  log ""

  if [[ -t 0 ]]; then
    read -r _
    return 0
  fi

  fail "Capturing both Duo displays needs an interactive terminal. Run once with SCREENSHOTS_DUO_DISPLAY=outer and once with SCREENSHOTS_DUO_DISPLAY=inner instead."
}

in_sets() {
  local candidate="$1"
  local set

  for set in "${SETS[@]}"; do
    [[ "$set" == "$candidate" ]] && return 0
  done

  return 1
}

# UDIDs live in <set>_udid.
udid_for() {
  describe_set "$1"
  local name="${1}_udid"
  printf '%s\n' "${!name:-}"
}

ensure_simulator_for_set() {
  local set="$1"
  local udid=""
  local device_type

  describe_set "$set"

  # Split on whitespace so the value's layout cannot leak into an identifier.
  for device_type in $SET_DEVICE_TYPES; do
    if udid="$(ensure_simulator "$SET_SIMULATOR" "$device_type")"; then
      break
    fi
    udid=""
  done

  [[ -n "$udid" ]] || fail "Unable to provision a simulator for the $set set"

  printf -v "${set}_udid" '%s' "$udid"
}

# Duo is the default set: it is what Duo support added, and iOS 27.1 SDK
# submissions require it from April 2027.
resolve_sets() {
  local raw="${SCREENSHOTS_SETS:-duo}"
  local entry

  SETS=()
  for entry in ${raw//,/ }; do
    case "$entry" in
      all)
        SETS=(iphone ipad duo)
        ;;
      iphone | ipad | duo)
        SETS+=("$entry")
        ;;
      "")
        ;;
      *)
        fail "Unknown screenshot set '$entry'. Use iphone, ipad, duo, or all."
        ;;
    esac
  done

  [[ ${#SETS[@]} -gt 0 ]] || fail "No screenshot sets selected"
}

in_sets() {
  local candidate="$1"
  local set

  for set in "${SETS[@]}"; do
    [[ "$set" == "$candidate" ]] && return 0
  done

  return 1
}

duo_display=""

resolve_duo_display() {
  case "${SCREENSHOTS_DUO_DISPLAY:-outer}" in
    outer | inner | both) duo_display="${SCREENSHOTS_DUO_DISPLAY:-outer}" ;;
    *) fail "SCREENSHOTS_DUO_DISPLAY must be outer, inner, or both" ;;
  esac
}

usage() {
  cat >&2 <<EOF
Usage: scripts/app_store_screenshots.sh [capture|upload VERSION_LOCALIZATION_ID|capture-upload VERSION_LOCALIZATION_ID]

Screenshot sets are chosen with SCREENSHOTS_SETS (default: duo).
  SCREENSHOTS_SETS=duo     iPhone Duo only
  SCREENSHOTS_SETS=all     iPhone, iPad, and iPhone Duo

The Duo shows one display at a time, so its two sets need opposite poses.
Choose with SCREENSHOTS_DUO_DISPLAY (default: outer).
  outer   Capture the outer display; device folded.
  inner   Capture the inner display; device unfolded.
  both    Capture outer, pause for you to unfold, then capture inner.

Open Device Hub (Xcode 27.1 > Open Developer Tool > Device Hub) and set the
pose before capturing. Blank captures fail with instructions rather than
uploading black screenshots.
EOF
}

# The environment wins over .env, so just recipes can override file defaults.
snapshot_preset_env() {
  PRESET_ENV=()

  local name
  for name in "${PRESERVED_ENV_NAMES[@]}"; do
    if [[ -n "${!name:-}" ]]; then
      PRESET_ENV+=("$name=${!name}")
    fi
  done
}

restore_preset_env() {
  local entry
  local name

  for entry in "${PRESET_ENV[@]:-}"; do
    [[ -n "$entry" ]] || continue
    name="${entry%%=*}"
    printf -v "$name" '%s' "${entry#*=}"
    export "${name?}"
  done
}

# Keys recipes set that .env.example also defines.
PRESERVED_ENV_NAMES=(
  SCREENSHOTS_SETS
  SCREENSHOTS_DUO_DISPLAY
  SCREENSHOTS_UPLOAD_APPEND
)

snapshot_preset_env
load_env_file "$env_file"
restore_preset_env
normalize_auth_env
build_asc_args
configure
resolve_sets
resolve_duo_display

# Provision only the selected sets; each first boot costs minutes of migration.
iphone_udid=""
ipad_udid=""
duo_udid=""

for selected_set in "${SETS[@]}"; do
  ensure_simulator_for_set "$selected_set"
done

case "${1:-capture}" in
  capture)
    build_app
    capture_all
    ;;
  upload)
    upload_screenshots "${2:-}"
    ;;
  capture-upload)
    build_app
    capture_all
    upload_screenshots "${2:-}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
