#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/Coverage"
RESULT_BUNDLE="$ROOT_DIR/.build/coverage/PikaCoverage.xcresult"
THRESHOLD="90.0"

rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

xcodebuild test \
  -project "$ROOT_DIR/pika.xcodeproj" \
  -scheme "pika" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:pikaTests \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO

COVERAGE_JSON="$(xcrun xccov view --report --json "$RESULT_BUNDLE")"

LINE_COVERAGE_PERCENT="$(COVERAGE_JSON="$COVERAGE_JSON" /usr/bin/python3 - <<'PY'
import json
import os

report = json.loads(os.environ["COVERAGE_JSON"])
coverage = report.get("lineCoverage")
if coverage is None:
    raise SystemExit("error: xccov report did not include lineCoverage")

print(f"{coverage * 100:.2f}")
PY
)"

printf 'Whole-codebase line coverage: %s%%\n' "$LINE_COVERAGE_PERCENT"

/usr/bin/python3 - "$LINE_COVERAGE_PERCENT" "$THRESHOLD" <<'PY'
import sys

actual = float(sys.argv[1])
threshold = float(sys.argv[2])
if actual < threshold:
    print(
        f"error: line coverage {actual:.2f}% is below required threshold {threshold:.2f}%",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
