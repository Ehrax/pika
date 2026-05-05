#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/Test"
RESULT_BUNDLE="$ROOT_DIR/.build/test/BillbiTests.xcresult"

rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

xcodebuild test \
  -project "$ROOT_DIR/billbi.xcodeproj" \
  -scheme "Billbi Dev" \
  -configuration "Debug Dev" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:billbiTests \
  -parallel-testing-enabled NO \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO
