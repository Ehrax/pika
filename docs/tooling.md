# Tooling

Pika uses project-local scripts for repeatable build, test, coverage, and metrics commands. The scripts keep Xcode output under `.build/` where practical so repeated runs do not depend on global DerivedData state.

## macOS Build And Run

Run the macOS app with:

```bash
./script/build_and_run.sh
```

The script stops any running `Pika` or `pika` process, builds the `pika` scheme from `pika.xcodeproj` for `platform=macOS` with code signing disabled, locates the built `pika.app` or `Pika.app` under `.build/DerivedData/Run`, and launches it with `/usr/bin/open -n`.

The Codex Run action calls:

```bash
./script/build_and_run.sh --verify
```

`--verify` waits briefly after launch and fails if neither a `pika` nor `Pika` process is running.

## Unit Tests

Run the reliable scaffold test gate with:

```bash
./script/test.sh
```

This runs unit tests only, with code coverage enabled:

```bash
xcodebuild test -project pika.xcodeproj -scheme pika -destination 'platform=macOS' -only-testing:pikaTests -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```

The baseline generated UI test target is not part of the scaffold coverage gate because it may be flaky or noisy at this stage.

## Coverage

Run coverage enforcement with:

```bash
./script/coverage.sh
```

The coverage script runs `pikaTests` into `.build/coverage/PikaCoverage.xcresult`, extracts Xcode line coverage with:

```bash
xcrun xccov view --report --json .build/coverage/PikaCoverage.xcresult
```

It prints two numbers:

- Raw Xcode line coverage for the full report.
- Testable production logic line coverage, which is the enforced gate.

The enforced gate intentionally excludes SwiftUI/design scaffold files and generated test targets that do not provide useful unit-test confidence in this pass:

- `pika/DesignSystem/`
- `pika/Shell/`
- `pika/Support/PreviewSupport.swift`
- `pikaTests/`
- `pikaUITests/`

The script enforces a 90% minimum line coverage threshold on testable production logic. It exits nonzero when that filtered coverage is below 90%.

## iOS Simulator Build And Test

The project is multiplatform, so simulator destinations can be used for iOS and iPadOS checks. One previously verified iPhone 17 simulator id was:

```text
03DD3B20-7426-40A9-AB86-6697C1C26639
```

Example iOS simulator unit test command:

```bash
xcodebuild test -project pika.xcodeproj -scheme pika -destination 'platform=iOS Simulator,id=03DD3B20-7426-40A9-AB86-6697C1C26639' -only-testing:pikaTests -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```

Change the destination id or destination spec as needed for the local simulator you want to use.

## Metrics

The ambiguous "crab/Carp" metrics request is resolved to Lizard because it is a small, common complexity tool with Swift support. Run metrics with:

```bash
./script/metrics.sh
```

The script runs `lizard --version` and then:

```bash
lizard -l swift pika
```

If the command exits with code 2, Lizard is the chosen metrics command but is unavailable on the machine. Install it with:

```bash
python3 -m pip install lizard
```
