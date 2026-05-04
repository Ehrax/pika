#!/usr/bin/env bash
set -euo pipefail

MODE="run"
WORKSPACE_SEED="empty"
PERSISTENCE_MODE=""
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/Run"
PROJECT_FILE="$ROOT_DIR/pika.xcodeproj"
SCHEME="Pika Dev"
CONFIGURATION="Debug Dev"
DESTINATION="platform=macOS"
APP_EXECUTABLE="pika-dev"
APP_BUNDLE_NAME="pika-dev.app"

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
    --dev|dev)
      SCHEME="Pika Dev"
      CONFIGURATION="Debug Dev"
      APP_EXECUTABLE="pika-dev"
      APP_BUNDLE_NAME="pika-dev.app"
      ;;
    --prod|prod)
      SCHEME="Pika Prod"
      CONFIGURATION="Debug Prod"
      APP_EXECUTABLE="pika"
      APP_BUNDLE_NAME="pika.app"
      ;;
    --release-prod|release-prod)
      SCHEME="Pika Prod"
      CONFIGURATION="Release Prod"
      APP_EXECUTABLE="pika"
      APP_BUNDLE_NAME="pika.app"
      ;;
    --local|local)
      PERSISTENCE_MODE="local"
      ;;
    --in-memory|in-memory|--memory|memory)
      PERSISTENCE_MODE="in-memory"
      ;;
    -h|--help)
      echo "usage: $0 [run|--verify] [--dev|--prod|--release-prod] [--empty|--sample|--demo|--seeded|--bikepark] [--local|--in-memory]" >&2
      exit 0
      ;;
    *)
      echo "usage: $0 [run|--verify] [--dev|--prod|--release-prod] [--empty|--sample|--demo|--seeded|--bikepark] [--local|--in-memory]" >&2
      exit 2
      ;;
  esac
  shift
done

kill_running_app() {
  local pids
  pids="$(
    process_ids_for_executable "$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/pika-dev.app/Contents/MacOS/pika-dev"
    process_ids_for_executable "$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/pika.app/Contents/MacOS/pika"
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
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO
}

find_app_bundle() {
  local products_dir="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION"

  if [[ -d "$products_dir/$APP_BUNDLE_NAME" ]]; then
    printf '%s\n' "$products_dir/$APP_BUNDLE_NAME"
    return 0
  fi

  find "$DERIVED_DATA_DIR/Build/Products" -maxdepth 3 -type d -name "$APP_BUNDLE_NAME" -print -quit
}

launch_app() {
  local app_bundle="$1"

  local launch_args=(--pika-workspace-seed "$WORKSPACE_SEED")
  if [[ -n "$PERSISTENCE_MODE" ]]; then
    launch_args+=(--pika-persistence "$PERSISTENCE_MODE")
  fi

  /usr/bin/open -n "$app_bundle" --args "${launch_args[@]}"
}

verify_launch() {
  local app_bundle="$1"
  local executable_path="$app_bundle/Contents/MacOS/$APP_EXECUTABLE"
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
