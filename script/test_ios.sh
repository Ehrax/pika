#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/Test-iOS"
RESULT_BUNDLE="$ROOT_DIR/.build/test/PikaTests-iOS.xcresult"

if [[ -z "${IOS_DESTINATION:-}" ]]; then
  IOS_DEVICE_ID="$(
    xcrun simctl list devices available |
      awk '/^[[:space:]]+iPhone 17 \(/ { gsub(/[()]/, ""); print $(NF - 1); exit }'
  )"

  if [[ -z "$IOS_DEVICE_ID" ]]; then
    IOS_DEVICE_ID="$(
      xcrun simctl list devices available |
        awk '/iPhone / { gsub(/[()]/, ""); print $(NF - 1); exit }'
    )"
  fi

  if [[ -z "$IOS_DEVICE_ID" ]]; then
    echo "error: no available iPhone simulator found. Set IOS_DESTINATION to a valid xcodebuild destination." >&2
    exit 2
  fi

  IOS_DESTINATION="platform=iOS Simulator,id=$IOS_DEVICE_ID"
fi

rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

xcodebuild test \
  -project "$ROOT_DIR/pika.xcodeproj" \
  -scheme "pika" \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:pikaTests \
  CODE_SIGNING_ALLOWED=NO
