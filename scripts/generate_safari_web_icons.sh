#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SOURCE_ICON="$ROOT_DIR/Apps/macOS/Resources/AppIcon.disabled/icon_512x512@2x.png"
OUTPUT_DIR="$ROOT_DIR/Extensions/SafariWeb/Resources/images"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/inspect-safari-icons.XXXXXX")"
LOCK_DIR="${TMPDIR:-/tmp}/inspect-safari-icons.lock"

while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  sleep 0.1
done

cleanup() {
  rm -rf "$TMP_DIR"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

render_icon() {
  size="$1"
  destination="$2"
  temporary_output="$TMP_DIR/$(basename "$destination").tmp.png"

  mkdir -p "$(dirname "$destination")"
  rm -f "$temporary_output"
  sips -z "$size" "$size" "$SOURCE_ICON" --out "$temporary_output" >/dev/null
  mv -f "$temporary_output" "$destination"
}

for size in 48 96 128 256 512; do
  render_icon "$size" "$OUTPUT_DIR/icon-$size.png"
done
