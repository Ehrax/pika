# Pika

## Mission

- Build Pika as a polished SwiftUI app for freelance invoicing across iOS, iPadOS, and macOS.
- Keep the app small, native, testable, and ready to grow without locking in premature architecture.

## Tooling

- Use the `fff` MCP tools for file discovery and code search first: `find_files` for names, `grep` or `multi_grep` for contents.
- Use the Build iOS Apps `ios-debugger-agent` skill and XcodeBuildMCP for simulator builds, launches, UI inspection, screenshots, logs, and debugging.
- Use XcodeBuildMCP to verify work through the real app whenever behavior or UI changes. Compile success alone is not enough.
- When implementing a feature, add useful telemetry for yourself with `Logger` / `os.Logger` or the project's established logging helper so simulator runs and logs can prove what happened.

## Source Of Truth

- App behavior: `pika/`
- Unit tests: `pikaTests/`
- UI tests and launch checks: `pikaUITests/`
- Xcode project configuration: `pika.xcodeproj/`
- Product and architecture notes: `docs/`

## Workflow

- Use test-driven development for feature work, bug fixes, refactors, and behavior changes: write the failing test, watch it fail for the right reason, implement the smallest change, then refactor while green.
- Keep tests focused on user-visible behavior, domain rules, persistence boundaries, and regressions. Do not add shallow tests just to make numbers look better.
- Use CRAP metrics as a signal, not a ritual. For changed code, look for high-complexity or poorly covered areas and improve the risky parts; do not over-optimize low-risk glue code.
- Prefer small, composable SwiftUI views and MV-first flow: views own local presentation state, models/services own behavior, and dependencies are injected through SwiftUI environment or narrow initializers.
- Before closing work, run focused tests plus the relevant XcodeBuildMCP build/run/debug workflow. Use simulator UI inspection, screenshots, and logs when the change has visible or runtime behavior.
- During feature development, commit after every meaningful, verified change using the `commit` skill. Keep commits small, conventional, and focused on one coherent step.

## Guardrails

- Read the current code and design notes before changing behavior. Preserve unrelated user changes.
- Keep platform behavior native: iPhone stack navigation, iPad adaptive layouts, and macOS desktop patterns where applicable.
- Do not harden SwiftData schema, CloudKit sync, PDF generation, invoice numbering, or billing abstractions before the feature actually needs them.
- Keep telemetry lightweight and remove noisy temporary probes before finishing unless they remain useful product/debug instrumentation.

## Avoid

- Do not skip TDD because the change looks small.
- Do not rely only on manual inspection, previews, or a successful build when automated tests or simulator verification can prove the behavior.
- Do not chase CRAP or coverage numbers mechanically; use them to guide judgment.
- Do not add broad architecture, shared helpers, or design-system components before there is real duplication or a clear local pattern.
