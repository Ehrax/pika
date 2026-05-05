# Billbi

## Mission

- Build Billbi as a polished SwiftUI macOS app for freelance invoicing.
- Keep the app small, native, testable, and ready to grow without locking in premature architecture.

## Tooling

- Use the `fff` MCP tools for file discovery and code search first: `find_files` for names, `grep` or `multi_grep` for contents.
- Use macOS build/run/debug tooling (including XcodeBuildMCP when useful) to investigate runtime behavior, launch failures, logs, screenshots, or UI state.
- Add lightweight telemetry with `Logger` / `os.Logger` or the project's established logging helper when it will help diagnose runtime behavior.

## Skills

- build-ios-apps:ios-app-intents: Use when exposing actions/content to Shortcuts, Siri, Spotlight, widgets, controls, or other intent-driven system surfaces.
- build-ios-apps:ios-debugger-agent: Use when running/debugging the app on a booted iOS simulator, inspecting runtime UI state, capturing logs, or diagnosing launch/runtime behavior.
- build-ios-apps:ios-ettrace-performance: Use when profiling iOS simulator performance and symbolicated flamegraphs for launch/runtime latency.
- build-ios-apps:ios-memgraph-leaks: Use when investigating iOS memory leaks, retain cycles, or memory growth with memgraph/leaks evidence.
- build-ios-apps:swiftui-liquid-glass: Use when adopting or reviewing iOS 26+ Liquid Glass API usage in SwiftUI.
- build-ios-apps:swiftui-performance-audit: Use when auditing or improving SwiftUI rendering/runtime performance.
- build-ios-apps:swiftui-ui-patterns: Use when creating/refactoring SwiftUI views, navigation, layout, and component patterns.
- build-ios-apps:swiftui-view-refactor: Use when splitting oversized SwiftUI views, stabilizing data flow, and tightening Observation/dependency injection patterns.
- build-macos-apps:appkit-interop: Use when bridging SwiftUI to AppKit for window access, responder chain behavior, panels, menus, or unsupported desktop interactions.
- build-macos-apps:build-run-debug: Use when building, running, launching, and debugging local macOS app/runtime/compiler issues.
- build-macos-apps:liquid-glass: Use when adopting/refactoring macOS SwiftUI UI for the new design system and Liquid Glass.
- build-macos-apps:packaging-notarization: Use when preparing archives and troubleshooting macOS packaging/signing/notarization readiness.
- build-macos-apps:signing-entitlements: Use when diagnosing signing failures, missing entitlements, hardened runtime, sandbox, or Gatekeeper trust-policy issues.
- build-macos-apps:swiftpm-macos: Use when working in SwiftPM-first macOS packages/executables without requiring Xcode project workflows.
- build-macos-apps:swiftui-patterns: Use when building/refactoring native macOS SwiftUI scenes, commands, toolbars, settings, split views, inspectors, and menu bar flows.
- build-macos-apps:telemetry: Use when adding runtime instrumentation with `Logger`/`os.Logger` and verifying expected events in logs.
- build-macos-apps:test-triage: Use when running/triaging failing macOS tests and separating regressions from setup/environment issues.
- build-macos-apps:view-refactor: Use when refactoring macOS SwiftUI scenes/views into smaller components with stable selection/state ownership.
- build-macos-apps:window-management: Use when customizing macOS window behavior, placement, chrome, drag regions, restoration, and utility/borderless window patterns.

## Source Of Truth

- App behavior: `billbi/`
- Unit tests: `billbiTests/`
- macOS UI tests and launch checks: `billbiUITests/`
- Xcode project configuration: `billbi.xcodeproj/`
- Product and architecture notes: `docs/`

## Workflow

- Prefer test-driven development for behavior changes, bug fixes, and risky refactors: write the failing test, watch it fail for the right reason, implement the smallest change, then refactor while green.
- Keep tests focused on user-visible behavior, domain rules, persistence boundaries, and regressions.
- For docs, previews, visual polish, mechanical cleanup, or low-risk SwiftUI composition, use judgment instead of forcing a test-first workflow.
- Prefer small, composable SwiftUI views and MV-first flow: views own local presentation state, models/services own behavior, and dependencies are injected through SwiftUI environment or narrow initializers.
- Before closing work, run focused checks that match the risk of the change.
- When committing, keep commits small, conventional, and focused on one coherent step.

## Guardrails

- Read the current code and design notes before changing behavior. Preserve unrelated user changes.
- Keep platform behavior native to macOS desktop patterns.
- Keep telemetry lightweight and remove noisy temporary probes before finishing unless they remain useful product/debug instrumentation.
