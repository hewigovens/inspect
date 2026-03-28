#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
source "$script_dir/lib/common.sh"

project_path="$repo_root/Inspect.xcodeproj"
configuration="Release"
export_options_plist="$repo_root/Configs/TestFlightExportOptions.plist"
env_file="${TESTFLIGHT_ENV_FILE:-$repo_root/.env}"
release_root="$repo_root/build/testflight"
archive_path="$release_root/Inspect.xcarchive"
export_path="$release_root/export"
app_id=""
group=""
build_version=""
build_number=""
exported_artifact_path=""
exported_platform=""

configure() {
  require_command xcbeautify
  app_id="${ASC_APP_ID:-}"
  group="${TESTFLIGHT_GROUP:-}"

  require_command xcodegen
  require_command xcodebuild
}

validate_app_access() {
  require_command asc
  require_value ASC_APP_ID

  log "Validating App Store Connect access for app $app_id"
  run_asc apps get --id "$app_id" --output json >/dev/null || {
    fail "Unable to access App Store Connect app $app_id."
  }
}

archive_build() {
  local -a archive_command
  local -a export_command

  build_xcode_auth_args
  generate_xcode_project "$repo_root"

  mkdir -p "$release_root"
  rm -rf "$archive_path" "$export_path"

  archive_command=(
    -scheme "${TESTFLIGHT_SCHEME:-Inspect}"
    -project "$project_path"
    -configuration "${TESTFLIGHT_CONFIGURATION:-$configuration}"
    -destination "${TESTFLIGHT_DESTINATION:-generic/platform=iOS}"
    -archivePath "$archive_path"
  )

  if is_truthy "${TESTFLIGHT_ALLOW_PROVISIONING_UPDATES:-true}"; then
    archive_command+=(-allowProvisioningUpdates)
  fi

  if [[ -n "${TESTFLIGHT_VERSION:-}" ]]; then
    archive_command+=("MARKETING_VERSION=${TESTFLIGHT_VERSION}")
  fi

  if [[ -n "${TESTFLIGHT_BUILD_NUMBER:-}" ]]; then
    archive_command+=("CURRENT_PROJECT_VERSION=${TESTFLIGHT_BUILD_NUMBER}")
  fi

  if [[ ${#XCODE_AUTH_ARGS[@]} -gt 0 ]]; then
    archive_command+=("${XCODE_AUTH_ARGS[@]}")
  fi

  archive_command+=(archive)

  log "Archiving Inspect"
  run_xcodebuild "${archive_command[@]}"

  export_command=(
    -exportArchive
    -archivePath "$archive_path"
    -exportPath "$export_path"
    -exportOptionsPlist "$export_options_plist"
  )

  if is_truthy "${TESTFLIGHT_ALLOW_PROVISIONING_UPDATES:-true}"; then
    export_command+=(-allowProvisioningUpdates)
  fi

  if [[ ${#XCODE_AUTH_ARGS[@]} -gt 0 ]]; then
    export_command+=("${XCODE_AUTH_ARGS[@]}")
  fi

  log "Exporting archive"
  run_xcodebuild "${export_command[@]}"

  exported_artifact_path="$(find "$export_path" -maxdepth 1 -type f \( -name '*.ipa' -o -name '*.pkg' \) -print -quit)"
  if [[ -z "$exported_artifact_path" ]]; then
    fail "No IPA or PKG was exported to $export_path"
  fi

  case "$exported_artifact_path" in
    *.pkg) exported_platform="MAC_OS" ;;
    *)     exported_platform="IOS" ;;
  esac
}

read_archive_build_metadata() {
  build_version="$(plutil -extract 'ApplicationProperties.CFBundleShortVersionString' raw -o - "$archive_path/Info.plist")"
  build_number="$(plutil -extract 'ApplicationProperties.CFBundleVersion' raw -o - "$archive_path/Info.plist")"
}

wait_for_build_processing() {
  local timeout="${TESTFLIGHT_TIMEOUT:-30m}"
  local poll_interval="${TESTFLIGHT_POLL_INTERVAL_SECONDS:-30}"
  local deadline

  require_command python3

  deadline=$((SECONDS + ${timeout%m} * 60))
  if [[ "$timeout" == *h ]]; then
    deadline=$((SECONDS + ${timeout%h} * 3600))
  elif [[ "$timeout" == *s ]]; then
    deadline=$((SECONDS + ${timeout%s}))
  elif [[ "$timeout" == "0" ]]; then
    deadline=0
  fi

  while true; do
    local build_json
    local build_state

    if ! build_json="$(run_asc builds find --app "$app_id" --build-number "$build_number" --output json 2>/dev/null)"; then
      build_json='{"data":null}'
    fi

    build_state="$(
      printf '%s' "$build_json" | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
item = payload.get("data")
if not item:
    sys.exit(0)

state = item.get("attributes", {}).get("processingState", "")
if state:
    print(state)
'
    )"

    case "$build_state" in
      "")
        log "==> Build $build_version ($build_number) is not visible in App Store Connect yet"
        ;;
      VALID)
        log "==> Build $build_version ($build_number) is VALID in App Store Connect"
        return 0
        ;;
      PROCESSING)
        log "==> Build $build_version ($build_number) is still processing"
        ;;
      FAILED|INVALID)
        fail "Build $build_version ($build_number) entered state $build_state."
        ;;
      *)
        log "==> Build $build_version ($build_number) state: $build_state"
        return 0
        ;;
    esac

    if [[ "$deadline" -ne 0 && "$SECONDS" -ge "$deadline" ]]; then
      fail "Timed out waiting for build $build_version ($build_number) to finish processing."
    fi

    sleep "$poll_interval"
  done
}

upload_build() {
  local locale="${TESTFLIGHT_LOCALE:-en-US}"
  local artifact_flag="--ipa"
  local -a command_args

  read_archive_build_metadata

  if [[ "$exported_platform" == "MAC_OS" ]]; then
    artifact_flag="--pkg"
  fi

  log "Exported artifact: $exported_artifact_path ($exported_platform)"
  log "Archive metadata: version $build_version build $build_number"

  if [[ -n "$group" ]]; then
    command_args=(
      publish testflight
      --app "$app_id"
      "$artifact_flag" "$exported_artifact_path"
      --group "$group"
      --platform "$exported_platform"
    )

    if is_truthy "${TESTFLIGHT_WAIT:-true}"; then
      command_args+=(--wait)
    fi

    if [[ -n "${TESTFLIGHT_TIMEOUT:-}" ]]; then
      command_args+=(--timeout "${TESTFLIGHT_TIMEOUT}")
    fi

    if is_truthy "${TESTFLIGHT_NOTIFY:-false}"; then
      command_args+=(--notify)
    fi

    if [[ -n "${TESTFLIGHT_NOTES:-}" ]]; then
      command_args+=(--test-notes "${TESTFLIGHT_NOTES}" --locale "$locale")
    fi

    log "Uploading and distributing to TestFlight group $group"
    run_asc "${command_args[@]}"
    return 0
  fi

  command_args=(
    builds upload
    --app "$app_id"
    "$artifact_flag" "$exported_artifact_path"
    --version "$build_version"
    --build-number "$build_number"
  )

  if [[ -n "${TESTFLIGHT_NOTES:-}" ]]; then
    command_args+=(--test-notes "${TESTFLIGHT_NOTES}" --locale "$locale")
  fi

  if is_truthy "${TESTFLIGHT_DRY_RUN:-false}"; then
    command_args+=(--dry-run)
  fi

  log "Uploading build to App Store Connect"
  run_asc "${command_args[@]}"

  if ! is_truthy "${TESTFLIGHT_DRY_RUN:-false}" && is_truthy "${TESTFLIGHT_WAIT:-true}"; then
    wait_for_build_processing
  fi
}

usage() {
  printf '%s\n' "Usage: scripts/testflight.sh [upload|build|dry-run]" >&2
}

load_env_file "$env_file"
normalize_auth_env
build_asc_args
configure

case "${1:-upload}" in
  upload)
    validate_app_access
    archive_build
    upload_build
    ;;
  build)
    archive_build
    read_archive_build_metadata
    log "Exported artifact: $exported_artifact_path ($exported_platform)"
    log "Archive metadata: version $build_version build $build_number"
    ;;
  dry-run)
    export TESTFLIGHT_DRY_RUN=true
    validate_app_access
    archive_build
    upload_build
    ;;
  *)
    usage
    exit 1
    ;;
esac
