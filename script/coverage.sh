#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.build/DerivedData/Coverage"
RESULT_BUNDLE="$ROOT_DIR/.build/coverage/PikaCoverage.xcresult"
COVERAGE_REPORT="$ROOT_DIR/.build/coverage/xccov-report.json"
THRESHOLD="90.0"

rm -rf "$RESULT_BUNDLE"
mkdir -p "$(dirname "$RESULT_BUNDLE")"

xcodebuild test \
  -project "$ROOT_DIR/pika.xcodeproj" \
  -scheme "Pika Dev" \
  -configuration "Debug Dev" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:pikaTests \
  -parallel-testing-enabled NO \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO

xcrun xccov view --report --json "$RESULT_BUNDLE" > "$COVERAGE_REPORT"

read -r RAW_LINE_COVERAGE_PERCENT GATED_LINE_COVERAGE_PERCENT < <(ROOT_DIR="$ROOT_DIR" /usr/bin/python3 - "$COVERAGE_REPORT" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "r", encoding="utf-8") as report_file:
    report = json.load(report_file)
root = os.environ["ROOT_DIR"]
raw_coverage = report.get("lineCoverage")
if raw_coverage is None:
    raise SystemExit("error: xccov report did not include lineCoverage")

excluded_path_parts = (
    "/pika/DesignSystem/",
    "/pika/Shell/",
    "/pikaUITests/",
    "/pikaTests/",
)
excluded_files = {
    f"{root}/pika/Support/PreviewSupport.swift",
}

covered_lines = 0
executable_lines = 0
for target in report.get("targets", []):
    if target.get("name") not in ("pika-dev.app", "pika.app"):
        continue

    for file_report in target.get("files", []):
        path = file_report.get("path", "")
        if path in excluded_files or any(part in path for part in excluded_path_parts):
            continue

        covered_lines += int(file_report.get("coveredLines", 0))
        executable_lines += int(file_report.get("executableLines", 0))

if executable_lines == 0:
    raise SystemExit("error: no executable production logic lines found for coverage gate")

gated_coverage = covered_lines / executable_lines
print(f"{raw_coverage * 100:.2f} {gated_coverage * 100:.2f}")
PY
)

printf 'Raw Xcode line coverage: %s%%\n' "$RAW_LINE_COVERAGE_PERCENT"
printf 'Testable production logic line coverage: %s%%\n' "$GATED_LINE_COVERAGE_PERCENT"

/usr/bin/python3 - "$GATED_LINE_COVERAGE_PERCENT" "$THRESHOLD" <<'PY'
import sys

actual = float(sys.argv[1])
threshold = float(sys.argv[2])
if actual < threshold:
    print(
        f"error: testable production logic line coverage {actual:.2f}% is below required threshold {threshold:.2f}%",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
