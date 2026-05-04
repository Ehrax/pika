# Tooling

Pika uses project-local scripts for repeatable build, test, and coverage commands. The scripts keep Xcode output under `.build/` where practical so repeated runs do not depend on global DerivedData state.

## macOS Build And Run

Run the macOS app with:

```bash
./script/build_and_run.sh
```

The script stops any running copy of the app launched from `.build/DerivedData/Run`, builds the `Pika Dev` scheme from `pika.xcodeproj` for `platform=macOS` with code signing disabled, locates the built `pika-dev.app` under `.build/DerivedData/Run`, and launches it with `/usr/bin/open -n`.

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
xcodebuild test -project pika.xcodeproj -scheme 'Pika Dev' -configuration 'Debug Dev' -destination 'platform=macOS' -only-testing:pikaTests -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO
```

The baseline generated UI test target is not part of the scaffold coverage gate because SwiftUI lifecycle tests are noisy at this stage. UI confidence should come from later end-to-end tests around real product flows.

The shared `Pika Dev` and `Pika Prod` Xcode schemes also exclude `pikaUITests` from their Test actions, so Xcode's Test command and unfiltered scheme test runs stay on the reliable unit-test loop while the app is still settling.

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
xcodebuild test -project pika.xcodeproj -scheme 'Pika Dev' -configuration 'Debug Dev' -destination "$IOS_DESTINATION" -only-testing:pikaTests CODE_SIGNING_ALLOWED=NO
```

## Metrics

CRAP-style metrics are intentionally not part of this scaffold branch. They need coverage data plus a useful complexity signal, and that is better added once the app has enough executable logic for the metric to say something real.

## Persistence Modes

Pika persists workspace state through normalized SwiftData records. The app does not keep a legacy blob/plist workspace fallback.

- Default app launches use private CloudKit-backed persistence (`AppPersistenceMode.cloudKitPrivate`).
- Explicit seed imports (`--pika-workspace-seed`) run in local-only mode (`AppPersistenceMode.local`) and replace existing local data with a deterministic normalized import.
- Test and UI test runs use in-memory mode (`AppPersistenceMode.inMemory`) for isolation and repeatability.

## Development Data Policy

Pre-release persistence is intentionally no-migration. Legacy blob/plist workspace data is not imported into normalized records.

For development and test workflows this means local data may be reset as persistence evolves; use seed flags to rebuild deterministic local state when needed.
