#!/usr/bin/env bash
set -euo pipefail

VARIANT="local"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/ProdArtifact"
PROJECT_FILE="$ROOT_DIR/pika.xcodeproj"
PRODUCTS_DIR="$DERIVED_DATA_DIR/Build/Products/Release Prod"
SOURCE_APP="$PRODUCTS_DIR/pika.app"
SOURCE_DSYM="$PRODUCTS_DIR/pika.app.dSYM"

usage() {
  echo "usage: $0 [--local|--cloud]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local|local)
      VARIANT="local"
      ;;
    --cloud|cloud)
      VARIANT="cloud"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

case "$VARIANT" in
  local)
    ARTIFACT_DIR="$ROOT_DIR/.build/artifacts/PikaProdLocal"
    ZIP_NAME="pika-prod-local.zip"
    ;;
  cloud)
    ARTIFACT_DIR="$ROOT_DIR/.build/artifacts/PikaProdCloud"
    ZIP_NAME="pika-prod-cloud.zip"
    ;;
esac

set_plist_value() {
  local plist_path="$1"
  local key_path="$2"
  local value="$3"

  if /usr/libexec/PlistBuddy -c "Print :$key_path" "$plist_path" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key_path $value" "$plist_path"
  else
    /usr/libexec/PlistBuddy -c "Add :$key_path string $value" "$plist_path"
  fi
}

build_release_prod() {
  xcodebuild build \
    -project "$PROJECT_FILE" \
    -scheme "Pika Prod" \
    -configuration "Release Prod" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO
}

prepare_artifacts() {
  rm -rf "$ARTIFACT_DIR"
  mkdir -p "$ARTIFACT_DIR"

  ditto "$SOURCE_APP" "$ARTIFACT_DIR/pika.app"
  if [[ -d "$SOURCE_DSYM" ]]; then
    ditto "$SOURCE_DSYM" "$ARTIFACT_DIR/pika.app.dSYM"
  fi

  if [[ "$VARIANT" == "local" ]]; then
    local plist_path="$ARTIFACT_DIR/pika.app/Contents/Info.plist"
    if ! /usr/libexec/PlistBuddy -c "Print :LSEnvironment" "$plist_path" >/dev/null 2>&1; then
      /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$plist_path"
    fi
    set_plist_value "$plist_path" "LSEnvironment:PIKA_PERSISTENCE" "local"
  fi

  (
    cd "$ARTIFACT_DIR"
    rm -f "$ZIP_NAME"
    ditto -c -k --keepParent pika.app "$ZIP_NAME"
  )
}

build_release_prod
prepare_artifacts
open "$ARTIFACT_DIR"

printf '%s\n' "$ARTIFACT_DIR"
