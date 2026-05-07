# Billbi

## Mission

- Build Billbi as a polished SwiftUI macOS app for freelance invoicing.
- Keep the app small, native, testable, and ready to grow without locking in premature architecture.

## Tooling

- Use the `fff` MCP tools for file discovery and code search first: `find_files` for names, `grep` or `multi_grep` for contents.
- Use macOS build/run/debug tooling (including XcodeBuildMCP when useful) to investigate runtime behavior, launch failures, logs, screenshots, or UI state.
- Add lightweight telemetry with `Logger` / `os.Logger` or the project's established logging helper when it will help diagnose runtime behavior.

## Skills

- Use `tdd` for behavior changes, bug fixes, and risky refactors.
- Use macOS app skills for build/run/debug, test triage, SwiftUI refactors, AppKit/window work, packaging/signing, and telemetry when the task calls for them.
- Use iOS skills only when a change explicitly touches iOS, App Intents, simulator behavior, or cross-platform coverage.

## Source Of Truth

- App behavior: `billbi/`
- Unit tests: `billbiTests/`
- macOS UI tests and launch checks: `billbiUITests/`
- Xcode project configuration: `billbi.xcodeproj/`
- Product and architecture notes: `docs/`

## Workflow

- Use the `tdd` skill for every new implementation, behavior change, bug fix, or risky refactor. Work in vertical red-green-refactor slices: write one behavior-focused failing test, watch it fail for the right reason, implement the smallest change, get it green, then repeat.
- Keep tests focused on user-visible behavior, domain rules, persistence boundaries, and regressions.
- For docs, previews, visual polish, mechanical cleanup, or low-risk SwiftUI composition, use judgment instead of forcing a test-first workflow.
- Before closing work, run focused checks that match the risk of the change.
- When committing, keep commits small, conventional, and focused on one coherent step.

## Architecture

- Keep Billbi MV-first with light DDD language: SwiftUI views are presentation, `WorkspaceStore` is the app-facing Workspace Module, domain decisions live in workflow/policy modules, and persistence stays behind infrastructure modules.
- Prefer deep modules with small interfaces: use seams only when they create real leverage/locality, and avoid shallow pass-through modules that only move complexity around.
- Break massive SwiftUI views into small feature files: root views should wire layout/state/dependencies, while rows, sections, toolbars, sheets, dialogs, and empty states live beside the feature they serve.
- Do not define model classes, domain enums, reusable extensions, projections, parsers, or formatting helpers inside SwiftUI view files. Move them to `Models/`, `Support/`, or a focused feature file/folder.

## Dev App Launch

- Do not hand-roll unsigned dev launches with raw `xcodebuild` and `open` unless you are debugging the launch script itself. Use `./script/build_and_run.sh` so agents consistently build the `Billbi Dev` scheme with `CODE_SIGNING_ALLOWED=NO`, local DerivedData, the correct derived app bundle, and `/usr/bin/open -n`.
- Prefer verified launches while developing:
  - `./script/build_and_run.sh --verify --empty --local`
  - `./script/build_and_run.sh --verify --seeded --local`
  - `./script/build_and_run.sh --verify --bikepark --local`
- `--verify` waits briefly after launch and fails if the expected executable from `.build/DerivedData/Run` is not running. Treat that as the first launch-health check before investigating UI state.
- Seed flags map to deterministic workspace modes: `--empty`, `--seeded` / `--sample` / `--demo`, and `--bikepark` / `--bikepark-thunersee`. Pass `--local` for normal development so seed runs do not hit CloudKit.
- If a launch fails, first rerun the exact script command with `--verify`, then inspect the script output, the derived app path under `.build/DerivedData/Run/Build/Products/Debug Dev/`, and recent process/log output for `billbi-dev`.

## Testing

- Run the focused macOS unit-test gate with `./script/test.sh`. It runs `billbiTests` only, with coverage enabled, against `Billbi Dev` / `Debug Dev` on `platform=macOS` and `CODE_SIGNING_ALLOWED=NO`.
- Run iOS simulator unit coverage only when the touched behavior should work cross-platform: `./script/test_ios.sh`. Set `IOS_DESTINATION` when the default simulator selection is not right for the machine.
- Run `./script/coverage.sh` when changes touch meaningful production logic or when coverage risk matters; it enforces the project coverage threshold for testable production logic.
- Keep UI tests and launch checks focused on real product flows. The default unit-test loop intentionally excludes noisy scaffold UI tests.

## Debugging And Telemetry

- Use macOS build/run/debug tooling, including XcodeBuildMCP when useful, for launch failures, screenshots, runtime logs, and UI-state investigation.
- Add lightweight telemetry with `Logger` / `os.Logger` or the project's established logging helper when it helps future agents diagnose launch, persistence, seed import, navigation, or data-flow problems. Prefer stable event names and useful context fields; remove noisy temporary probes before finishing unless they remain useful product/debug instrumentation.
- When debugging persistence or seed behavior, record the seed and persistence mode in the investigation notes and prefer local or in-memory modes for repeatability.

## Guardrails

- Read the current code and design notes before changing behavior. Preserve unrelated user changes.
- Keep platform behavior native to macOS desktop patterns.
- Keep telemetry lightweight and remove noisy temporary probes before finishing unless they remain useful product/debug instrumentation.
