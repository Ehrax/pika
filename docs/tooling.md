# Tooling

Pika uses project-local scripts for repeatable build, test, and coverage commands. The scripts keep Xcode output under `.build/` where practical so repeated runs do not depend on global DerivedData state.

## macOS Build And Run

Run the macOS app with:

```bash
./script/build_and_run.sh
```

The script stops any running copy of the app launched from `.build/DerivedData/Run`, builds the `pika` scheme from `pika.xcodeproj` for `platform=macOS` with code signing disabled, locates the built `pika.app` or `Pika.app` under `.build/DerivedData/Run`, and launches it with `/usr/bin/open -n`.

The Codex Run action calls:

```bash
./script/build_and_run.sh --verify
```

`--verify` waits briefly after launch and fails if the expected executable from the built app bundle is not running.

## Unit Tests

Run the reliable scaffold test gate with:

```bash
./script/test.sh
```

This runs unit tests only, with code coverage enabled:

```bash
xcodebuild test -project pika.xcodeproj -scheme pika -destination 'platform=macOS' -only-testing:pikaTests -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```

The baseline generated UI test target is not part of the scaffold coverage gate because SwiftUI lifecycle tests are noisy at this stage. UI confidence should come from later end-to-end tests around real product flows.

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

The project is multiplatform, so simulator destinations can be used for iOS and iPadOS checks.

Run iOS simulator unit tests with:

```bash
./script/test_ios.sh
```

By default the script picks the first available iPhone 17 simulator, falling back to the first available iPhone simulator. Change the destination id or destination spec as needed for the local simulator you want to use:

```bash
IOS_DESTINATION='platform=iOS Simulator,id=03DD3B20-7426-40A9-AB86-6697C1C26639' ./script/test_ios.sh
```

The script runs:

```bash
xcodebuild test -project pika.xcodeproj -scheme pika -destination "$IOS_DESTINATION" -only-testing:pikaTests CODE_SIGNING_ALLOWED=NO
```

## Metrics

CRAP-style metrics are intentionally not part of this scaffold branch. They need coverage data plus a useful complexity signal, and that is better added once the app has enough executable logic for the metric to say something real.

## Scaffold Deferrals

The scaffold wires a minimal SwiftData `ModelContainer` around `ProjectRecord`, but CloudKit/iCloud entitlements are intentionally not added in this pass. The exact CloudKit container identifier and provisioning setup remain open product decisions, so the scaffold keeps that integration out of the project file until those values are known.

If a development machine has an incompatible local store left over from the starter SwiftData template, clear the app's local development container once before launching this scaffold. The scaffold does not perform a destructive runtime reset.
