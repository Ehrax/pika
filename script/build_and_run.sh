#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/Run"
PROJECT_FILE="$ROOT_DIR/pika.xcodeproj"
SCHEME="pika"
DESTINATION="platform=macOS"

kill_running_app() {
  pkill -x "Pika" >/dev/null 2>&1 || true
  pkill -x "pika" >/dev/null 2>&1 || true
}

build_app() {
  xcodebuild build \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO
}

find_app_bundle() {
  local products_dir="$DERIVED_DATA_DIR/Build/Products/Debug"

  if [[ -d "$products_dir/pika.app" ]]; then
    printf '%s\n' "$products_dir/pika.app"
    return 0
  fi

  if [[ -d "$products_dir/Pika.app" ]]; then
    printf '%s\n' "$products_dir/Pika.app"
    return 0
  fi

  find "$DERIVED_DATA_DIR/Build/Products" -maxdepth 3 -type d \( -name "pika.app" -o -name "Pika.app" \) -print -quit
}

launch_app() {
  local app_bundle="$1"
  /usr/bin/open -n "$app_bundle"
}

verify_launch() {
  sleep 2
  if pgrep -x "pika" >/dev/null 2>&1 || pgrep -x "Pika" >/dev/null 2>&1; then
    return 0
  fi

  echo "error: expected Pika process to be running after launch" >&2
  return 1
}

case "$MODE" in
  run|--verify|verify)
    kill_running_app
    build_app
    APP_BUNDLE="$(find_app_bundle)"
    if [[ -z "${APP_BUNDLE:-}" || ! -d "$APP_BUNDLE" ]]; then
      echo "error: built app bundle was not found under $DERIVED_DATA_DIR/Build/Products" >&2
      exit 1
    fi

    launch_app "$APP_BUNDLE"
    if [[ "$MODE" == "--verify" || "$MODE" == "verify" ]]; then
      verify_launch
    fi
    ;;
  *)
    echo "usage: $0 [run|--verify]" >&2
    exit 2
    ;;
esac
