# Billbi

## Mission

- Build Billbi as a polished native SwiftUI macOS app for freelance invoicing.
- Keep the app small, testable, and ready to grow without locking in premature architecture.

## Source Of Truth

- App behavior: `billbi/`; unit tests: `billbiTests/`; macOS UI tests and launch checks: `billbiUITests/`.
- Xcode project configuration: `billbi.xcodeproj/`; product and architecture notes: `docs/`.
- Use the `fff` MCP tools first for file discovery and code search: `find_files` for names, `grep` or `multi_grep` for contents.

## Workflow

- Read the current code and relevant design notes before changing behavior; preserve unrelated user changes.
- Use `tdd` for behavior changes, bug fixes, and risky refactors: write one behavior-focused failing test, confirm it fails for the right reason, implement the smallest change, get it green, then repeat.
- For docs, previews, visual polish, mechanical cleanup, or low-risk SwiftUI composition, use judgment instead of forcing test-first work.
- Keep tests focused on user-visible behavior, domain rules, persistence boundaries, and regressions.
- Before closing work, run focused checks that match the risk. When committing, keep commits small, conventional, and focused on one coherent step.

## Architecture

- Preserve the existing app shape unless the task explicitly changes architecture.
- Prefer deep modules with small interfaces; avoid shallow pass-through modules that only move complexity around.
- Break massive SwiftUI views into small feature files: root views wire layout/state/dependencies, while rows, sections, toolbars, sheets, dialogs, and empty states live beside the feature they serve.
- Do not define model classes, domain enums, reusable extensions, projections, parsers, or formatting helpers inside SwiftUI view files. Move them to `Models/`, `Support/`, or a focused feature file/folder.

## Localization

- Do not introduce hardcoded user-facing strings in Swift code.
- Billbi uses `billbi/Localizable.xcstrings` as the app string catalog; add new UI copy there and use SwiftUI localization APIs such as `LocalizedStringKey`, `Text("...")`, `Button("...")`, or `String(localized:)` for non-view strings.
- Keep internal identifiers, log event names, test names, and non-user-facing diagnostics as plain strings when appropriate.

## macOS Dev Loop

- Use macOS app skills and build/run/debug tooling, including XcodeBuildMCP when useful, for launch failures, screenshots, runtime logs, and UI-state investigation.
- Do not hand-roll unsigned dev launches with raw `xcodebuild` and `open` unless debugging the launch script itself. Use `./script/build_and_run.sh` so agents build the `Billbi Dev` scheme with local DerivedData and the correct derived app bundle.
- Prefer verified launches while developing: `./script/build_and_run.sh --verify --empty --local`, `./script/build_and_run.sh --verify --seeded --local`, or `./script/build_and_run.sh --verify --bikepark --local`.
- Seed flags map to deterministic workspace modes: `--empty`, `--seeded` / `--sample` / `--demo`, and `--bikepark` / `--bikepark-thunersee`. Pass `--local` for normal development so seed runs do not hit CloudKit.
- If a launch fails, rerun the exact script command with `--verify`, then inspect script output, the derived app under `.build/DerivedData/Run/Build/Products/Debug Dev/`, and recent `billbi-dev` process/log output.

## Testing

- Run the focused macOS unit-test gate with `./script/test.sh`; it runs `billbiTests` only, with coverage enabled, against `Billbi Dev` / `Debug Dev` on `platform=macOS` and `CODE_SIGNING_ALLOWED=NO`.
- Run iOS simulator unit coverage only when touched behavior should work cross-platform: `./script/test_ios.sh`. Set `IOS_DESTINATION` when the default simulator selection is not right for the machine.
- Run `./script/coverage.sh` when changes touch meaningful production logic or coverage risk matters.
- Keep UI tests and launch checks focused on real product flows; the default unit-test loop intentionally excludes noisy scaffold UI tests.

## Debugging And Telemetry

- Add lightweight telemetry with `Logger` / `os.Logger` or the project's established logging helper when it helps future agents diagnose launch, persistence, seed import, navigation, or data-flow problems.
- Prefer stable event names and useful context fields. Remove noisy temporary probes before finishing unless they remain useful product/debug instrumentation.
- When debugging persistence or seed behavior, record the seed and persistence mode in the investigation notes and prefer local or in-memory modes for repeatability.

## Platform Guardrails

- Keep platform behavior native to macOS desktop patterns.
- Use macOS app skills for build/run/debug, test triage, SwiftUI refactors, AppKit/window work, packaging/signing, and telemetry when the task calls for them.
- Use iOS skills only when a change explicitly touches iOS, App Intents, simulator behavior, or cross-platform coverage.
