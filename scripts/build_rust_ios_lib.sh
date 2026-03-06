#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SRCROOT:-}" || -z "${BUILT_PRODUCTS_DIR:-}" || -z "${PLATFORM_NAME:-}" || -z "${CONFIGURATION:-}" ]]; then
  echo "build_rust_ios_lib.sh requires Xcode build environment variables" >&2
  exit 1
fi

ARCH="${CURRENT_ARCH:-}"
if [[ -z "$ARCH" || "$ARCH" == "undefined_arch" ]]; then
  ARCH="${ARCHS%% *}"
fi

RUST_TARGETS=()

append_target() {
  local candidate="$1"
  for existing in "${RUST_TARGETS[@]:-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return
    fi
  done
  RUST_TARGETS+=("$candidate")
}

case "$PLATFORM_NAME" in
  iphoneos)
    append_target "aarch64-apple-ios"
    ;;
  iphonesimulator)
    for sim_arch in ${ARCHS:-$ARCH}; do
      case "$sim_arch" in
        arm64)
          append_target "aarch64-apple-ios-sim"
          ;;
        x86_64)
          append_target "x86_64-apple-ios"
          ;;
        *)
          echo "Unsupported simulator arch: $sim_arch" >&2
          exit 1
          ;;
      esac
    done
    ;;
  *)
    echo "Unsupported Apple platform: $PLATFORM_NAME" >&2
    exit 1
    ;;
esac

PROFILE="debug"
CARGO_ARGS=()
if [[ "$CONFIGURATION" == "Release" ]]; then
  PROFILE="release"
  CARGO_ARGS+=(--release)
fi

MANIFEST_PATH="$SRCROOT/Rust/inspect-tunnel-core/Cargo.toml"
DEST_PATH="$BUILT_PRODUCTS_DIR/libinspect_tunnel_core.a"
LIB_INPUTS=()

for rust_target in "${RUST_TARGETS[@]}"; do
  echo "Building inspect-tunnel-core for $rust_target ($PROFILE)"
  if [[ ${#CARGO_ARGS[@]} -gt 0 ]]; then
    cargo build --manifest-path "$MANIFEST_PATH" --target "$rust_target" "${CARGO_ARGS[@]}"
  else
    cargo build --manifest-path "$MANIFEST_PATH" --target "$rust_target"
  fi
  LIB_INPUTS+=("$SRCROOT/Rust/inspect-tunnel-core/target/$rust_target/$PROFILE/libinspect_tunnel_core.a")
done

mkdir -p "$BUILT_PRODUCTS_DIR"
if [[ ${#LIB_INPUTS[@]} -eq 1 ]]; then
  cp "${LIB_INPUTS[0]}" "$DEST_PATH"
else
  xcrun lipo -create "${LIB_INPUTS[@]}" -output "$DEST_PATH"
fi
echo "Copied inspect-tunnel-core to $DEST_PATH"
