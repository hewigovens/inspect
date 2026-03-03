log() {
  printf '%s\n' "$*"
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

load_env_file() {
  local env_file="$1"

  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "$command_name is not installed"
  fi
}

require_value() {
  local variable_name="$1"

  if [[ -z "${!variable_name:-}" ]]; then
    fail "$variable_name is required. Set it in .env or your shell."
  fi
}

is_truthy() {
  case "${1:-}" in
    1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Oo][Nn]) return 0 ;;
    *) return 1 ;;
  esac
}

expand_path() {
  local raw_path="$1"

  case "$raw_path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${raw_path#~/}"
      ;;
    *)
      printf '%s\n' "$raw_path"
      ;;
  esac
}

normalize_auth_env() {
  if [[ -z "${ASC_KEY_ID:-}" && -n "${APP_STORE_CONNECT_KEY_ID:-}" ]]; then
    export ASC_KEY_ID="$APP_STORE_CONNECT_KEY_ID"
  fi

  if [[ -z "${ASC_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    export ASC_ISSUER_ID="$APP_STORE_CONNECT_ISSUER_ID"
  fi

  if [[ -z "${ASC_PRIVATE_KEY_PATH:-}" && -n "${APP_STORE_CONNECT_KEY_PATH:-}" ]]; then
    export ASC_PRIVATE_KEY_PATH="$(expand_path "$APP_STORE_CONNECT_KEY_PATH")"
  fi
}

build_asc_args() {
  ASC_ARGS=()

  if [[ -n "${ASC_PROFILE:-}" ]]; then
    ASC_ARGS+=(--profile "$ASC_PROFILE")
  fi
}

run_asc() {
  if [[ ${#ASC_ARGS[@]} -gt 0 ]]; then
    asc "${ASC_ARGS[@]}" "$@"
  else
    asc "$@"
  fi
}

build_xcode_auth_args() {
  local key_path

  XCODE_AUTH_ARGS=()

  if [[ -z "${APP_STORE_CONNECT_KEY_ID:-}${APP_STORE_CONNECT_ISSUER_ID:-}${APP_STORE_CONNECT_KEY_PATH:-}" ]]; then
    return 0
  fi

  require_value APP_STORE_CONNECT_KEY_ID
  require_value APP_STORE_CONNECT_ISSUER_ID
  require_value APP_STORE_CONNECT_KEY_PATH

  key_path="$(expand_path "$APP_STORE_CONNECT_KEY_PATH")"
  if [[ ! -f "$key_path" ]]; then
    fail "APP_STORE_CONNECT_KEY_PATH does not exist: $key_path"
  fi

  XCODE_AUTH_ARGS=(
    -authenticationKeyPath "$key_path"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
}

run_xcodebuild() {
  local status

  set +e
  xcodebuild "$@" 2>&1 | xcbeautify
  status=${PIPESTATUS[0]}
  set -e

  return "$status"
}

generate_xcode_project() {
  local repo_root="$1"

  cd "$repo_root"
  log "Generating Xcode project"
  xcodegen generate
}
