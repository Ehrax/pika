#!/usr/bin/env bash
set -euo pipefail

MODE="run"
WORKSPACE_SEED="empty"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/Run"
RUN_DATA_DIR="$ROOT_DIR/.build/RunData"
PROJECT_FILE="$ROOT_DIR/pika.xcodeproj"
SCHEME="pika"
DESTINATION="platform=macOS"

while [[ $# -gt 0 ]]; do
  case "$1" in
    run|--verify|verify)
      MODE="$1"
      ;;
    --seeded|seeded|--preseeded|preseeded|--sample|sample|--demo|demo)
      WORKSPACE_SEED="sample"
      ;;
    --bikepark|bikepark|--bikepark-thunersee|bikepark-thunersee)
      WORKSPACE_SEED="bikepark-thunersee"
      ;;
    --empty|empty)
      WORKSPACE_SEED="empty"
      ;;
    -h|--help)
      echo "usage: $0 [run|--verify] [--empty|--sample|--demo|--seeded|--bikepark]" >&2
      exit 0
      ;;
    *)
      echo "usage: $0 [run|--verify] [--empty|--sample|--demo|--seeded|--bikepark]" >&2
      exit 2
      ;;
  esac
  shift
done

kill_running_app() {
  local pids
  pids="$(
    process_ids_for_executable "$DERIVED_DATA_DIR/Build/Products/Debug/pika.app/Contents/MacOS/pika"
    process_ids_for_executable "$DERIVED_DATA_DIR/Build/Products/Debug/Pika.app/Contents/MacOS/pika"
  )"
  if [[ -n "$pids" ]]; then
    kill $pids >/dev/null 2>&1 || true
  fi
}

process_ids_for_executable() {
  local executable_path="$1"
  ps -axo pid=,command= |
    awk -v executable_path="$executable_path" '
      {
        pid = $1
        sub(/^[[:space:]]*[0-9]+[[:space:]]+/, "", $0)
        if (index($0, executable_path) == 1) {
          print pid
        }
      }
    '
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
  local workspace_name="$WORKSPACE_SEED"

  local workspace_dir="$RUN_DATA_DIR/$workspace_name"
  local workspace_path="$workspace_dir/workspace.json"
  mkdir -p "$workspace_dir"
  rm -f "$workspace_path"

  /usr/bin/open -n "$app_bundle" --args \
    --pika-workspace-path "$workspace_path" \
    --pika-workspace-seed "$WORKSPACE_SEED"
}

verify_launch() {
  local app_bundle="$1"
  local executable_path="$app_bundle/Contents/MacOS/pika"
  sleep 2
  if [[ -n "$(process_ids_for_executable "$executable_path")" ]]; then
    return 0
  fi

  echo "error: expected launched app process to be running from $app_bundle" >&2
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
      verify_launch "$APP_BUNDLE"
    fi
    ;;
  *)
    echo "usage: $0 [run|--verify] [--empty|--sample|--demo|--seeded|--bikepark]" >&2
    exit 2
    ;;
esac
