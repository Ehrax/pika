# Pika

## Mission

- Build Pika as a polished SwiftUI app for freelance invoicing across iOS, iPadOS, and macOS.
- Keep the app small, native, testable, and ready to grow without locking in premature architecture.

## Tooling

- Use the `fff` MCP tools for file discovery and code search first: `find_files` for names, `grep` or `multi_grep` for contents.
- Use the Build iOS Apps `ios-debugger-agent` skill and XcodeBuildMCP when debugging runtime behavior, simulator-only issues, launch failures, logs, screenshots, or UI state.
- Add lightweight telemetry with `Logger` / `os.Logger` or the project's established logging helper when it will help diagnose runtime behavior.

## Source Of Truth

- App behavior: `pika/`
- Unit tests: `pikaTests/`
- UI tests and launch checks: `pikaUITests/`
- Xcode project configuration: `pika.xcodeproj/`
- Product and architecture notes: `docs/`

## Workflow

- Prefer test-driven development for behavior changes, bug fixes, and risky refactors: write the failing test, watch it fail for the right reason, implement the smallest change, then refactor while green.
- Keep tests focused on user-visible behavior, domain rules, persistence boundaries, and regressions. Do not add shallow tests just to make numbers look better.
- For docs, previews, visual polish, mechanical cleanup, or low-risk SwiftUI composition, use judgment instead of forcing a test-first workflow.
- Prefer small, composable SwiftUI views and MV-first flow: views own local presentation state, models/services own behavior, and dependencies are injected through SwiftUI environment or narrow initializers.
- Before closing work, run the focused checks that match the risk of the change. Use XcodeBuildMCP only when debugging or when simulator evidence is specifically useful.
- When committing, keep commits small, conventional, and focused on one coherent step.

## Guardrails

- Read the current code and design notes before changing behavior. Preserve unrelated user changes.
- Keep platform behavior native: iPhone stack navigation, iPad adaptive layouts, and macOS desktop patterns where applicable.
- Do not harden SwiftData schema, CloudKit sync, PDF generation, invoice numbering, or billing abstractions before the feature actually needs them.
- Keep telemetry lightweight and remove noisy temporary probes before finishing unless they remain useful product/debug instrumentation.

## Avoid

- Do not rely only on manual inspection, previews, or a successful build when automated tests would materially reduce risk.
- Do not add broad test, coverage, or metrics work that does not improve confidence in the change at hand.
- Do not add broad architecture, shared helpers, or design-system components before there is real duplication or a clear local pattern.
