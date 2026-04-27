# Pika Scaffold Architecture Design

## Summary

Create the project foundation for Pika without implementing the product UI or behavior yet.

This pass prepares the app to grow into the freelance invoicing product described in `2026-04-26-freelance-invoicing-app-design.md`. It should replace the default template shape with a clean multiplatform SwiftUI architecture, basic app prerequisites, and lightweight design-system infrastructure. The scaffold must be buildable, preview-friendly, and ready for SwiftData/iCloud-backed development later, but it must not harden the full domain model before the actual app implementation pass.

The product posture is: set up the rails now, keep the model flexible.

## Goals

- Establish a clean folder structure for a non-trivial iOS, iPadOS, and macOS SwiftUI app.
- Keep the app MV-first: SwiftUI views own local state, shared services live in the environment, and domain behavior belongs in models or services.
- Wire a minimal SwiftData container at the app root.
- Prepare the project for iCloud/CloudKit sync without overbuilding the data layer.
- Add placeholder design-system tokens based on the generated hi-fi design artifacts.
- Add minimal routing, sheet, store, service, and support boundaries.
- Add build/run prerequisites for local Codex and Xcode development.
- Add test and coverage prerequisites so future implementation work can follow test-driven development with measurable coverage.
- Remove or isolate the starter template app shape so future work starts from Pika-specific foundations.

## Non-Goals

- Do not implement project, bucket, invoice, dashboard, settings, or detail screens.
- Do not build the full component library yet.
- Do not finalize the app's complete SwiftData schema.
- Do not implement PDF generation, invoice numbering, billing logic, App Intents, widgets, import/export, or sync conflict handling.
- Do not create polished sample UI from the hi-fi designs.
- Do not adopt Liquid Glass APIs.
- Do not bundle custom fonts. Use Apple system font APIs for now.
- Do not chase high coverage through empty tests, generated-code assertions, or tests that only exercise placeholder scaffolding.

## Platform Assumptions

- The app is a shared SwiftUI app targeting iOS, iPadOS, and macOS from one project.
- macOS should use desktop-native structure: stable selection, split-view readiness, toolbars, commands, and a dedicated settings scene when settings are implemented.
- iPhone should use stack-style navigation when real screens are added.
- iPad can share the adaptive root structure and later choose between compact stack and regular split layouts.
- The design system should support light and dark mode from the beginning.

## Architecture

### App

Owns the `@main` entrypoint, app scene declarations, SwiftData container creation, and app-wide environment wiring.

Expected files:

```text
pika/App/PikaApp.swift
pika/App/AppDependencyGraph.swift
```

Responsibilities:

- Declare the main `WindowGroup`.
- Install the shared `ModelContainer`.
- Install app-wide services and settings through a single dependency graph modifier.
- Keep app launch code small and readable.

### DesignSystem

Contains tokens and tiny helpers only in this scaffold pass.

Expected files:

```text
pika/DesignSystem/PikaColor.swift
pika/DesignSystem/PikaTypography.swift
pika/DesignSystem/PikaSpacing.swift
pika/DesignSystem/PikaRadius.swift
pika/DesignSystem/PikaStatusTone.swift
```

Responsibilities:

- Translate the current generated design tokens into native Swift names.
- Use semantic token names so the visual language can change without touching feature code.
- Use system fonts through SwiftUI font APIs.
- Avoid full component implementations in this pass.

### Navigation

Defines destination types and presentation infrastructure without real destinations.

Expected files:

```text
pika/Navigation/AppRoute.swift
pika/Navigation/SheetDestination.swift
pika/Navigation/AppRouter.swift
```

Responsibilities:

- Define lightweight route and sheet enums.
- Provide a small observable router type for future stack navigation and sheet presentation.
- Keep route payloads stable, simple, and value-based.
- Avoid storing view instances in navigation state.

### Models

Keeps only the minimum persisted model needed to prove SwiftData wiring.

Expected files:

```text
pika/Models/ProjectRecord.swift
```

Responsibilities:

- Replace the starter `Item` demo model with one Pika-named record.
- Keep fields intentionally small, for example an id, title, creation date, and archived flag.
- Avoid relationships and invoice-specific schema until the product implementation pass.
- Leave room for migration once the real model becomes clearer.

### Stores

Defines the boundary between UI and persistence without implementing product data flows.

Expected files:

```text
pika/Stores/ProjectStore.swift
```

Responsibilities:

- Define a small protocol or environment-accessible store shell for future project access.
- Keep the scaffold mostly protocol and type shape, not business behavior.
- Avoid sample repository complexity unless needed for previews.

### Services

Defines future service boundaries as thin placeholders.

Expected files:

```text
pika/Services/InvoicePDFService.swift
pika/Services/AppSettings.swift
```

Responsibilities:

- Reserve clear homes for PDF generation and app preferences.
- Keep implementations minimal or stubbed.
- Avoid invoice rendering logic in this scaffold pass.

### Shell

Contains only a minimal compile-safe root view.

Expected files:

```text
pika/Shell/RootView.swift
```

Responsibilities:

- Present a placeholder Pika root surface.
- Prove the app launches.
- Avoid implementing the real sidebar, dashboard, project list, bucket list, or invoice UI.

### Support

Holds small utilities that are safe to establish early.

Expected files:

```text
pika/Support/MoneyFormatting.swift
pika/Support/PreviewSupport.swift
```

Responsibilities:

- Add lightweight formatting and preview helpers only where they reduce future duplication.
- Keep helpers dependency-light and platform-safe.

## Persistence And Sync

The scaffold should be SwiftData-ready from the beginning, but not schema-heavy.

Initial persistence should:

- Create one shared `ModelContainer` at the app root.
- Include only the minimal Pika-named model.
- Keep CloudKit/iCloud readiness in the project setup and entitlements where feasible.
- Avoid full CloudKit sync behavior until the real domain model is implemented.

This means the app has the correct place for persistent data, but the next implementation pass can still reshape the schema without fighting premature relationships.

## Project Prerequisites

The scaffold should add or prepare:

- A project-local `script/build_and_run.sh` for macOS build/run verification.
- A project-local test command or script that runs the app and test targets with code coverage enabled.
- A project-local coverage report command or script that reads Xcode coverage output and prints line coverage.
- `.codex/environments/environment.toml` pointing the Codex Run action at that script.
- Entitlements files if needed for iCloud/CloudKit/App Sandbox setup.
- Clean generated Info.plist settings through the Xcode project where practical.
- A root app name and bundle setup that no longer reads as the default SwiftData template.

## Implementation Workflow Requirements

The scaffold implementation plan should explicitly require:

- `test-driven-development` for all production code changes that add behavior, refactor behavior, or fix bugs.
- `subagent-driven-development` for executing independent implementation tasks once a written plan exists.
- Fresh subagents for independent tasks, followed by spec-compliance review and code-quality review before a task is considered complete.
- No implementation work on `main` unless explicitly approved at execution time.
- Tests that verify real behavior and fail for the expected reason before production code is added.

Configuration-only changes, generated project metadata, and empty structural files may be handled as scaffold exceptions, but any executable logic introduced during the scaffold should have a failing test first.

## Relevant Native App Skills

The implementation plan should review the relevant iOS and macOS app skills before touching project structure. Not every skill is mandatory for the scaffold, but the agent should explicitly choose the ones that apply to each task.

### iOS Skills

- `build-ios-apps:swiftui-ui-patterns` for SwiftUI view, app wiring, navigation, sheets, previews, async state, and component guidance.
- `build-ios-apps:swiftui-view-refactor` for keeping SwiftUI views small, MV-first, stable, and explicitly injected.
- `build-ios-apps:ios-debugger-agent` for building, running, launching, inspecting, screenshotting, and debugging the app on an iOS simulator when simulator verification is needed.
- `build-ios-apps:ios-app-intents` for future App Intents, App Entities, App Shortcuts, and system-surface integrations. This is context for future work, not part of the scaffold implementation unless the plan deliberately adds intent placeholders.
- `build-ios-apps:swiftui-liquid-glass` for Liquid Glass review only if future work considers those APIs. This scaffold must not adopt Liquid Glass.
- `build-ios-apps:swiftui-performance-audit` for future reviews of janky scrolling, excessive view updates, or high CPU/memory behavior.
- `build-ios-apps:ios-ettrace-performance` for future ETTrace performance profiling of simulator flows.
- `build-ios-apps:ios-memgraph-leaks` for future memory graph and retain-cycle investigations.

### macOS Skills

- `build-macos-apps:swiftui-patterns` for macOS scene structure, windows, commands, settings, split views, inspectors, and desktop interaction patterns.
- `build-macos-apps:view-refactor` for keeping macOS SwiftUI scene roots small, explicit, stable, and split by responsibility.
- `build-macos-apps:build-run-debug` for project-local build/run script setup, Codex Run button wiring, launch verification, logs, and debugger workflows.
- `build-macos-apps:swiftpm-macos` if any future macOS package-first or SwiftPM executable workflow appears. The current app is Xcode-project based.
- `build-macos-apps:signing-entitlements` for app sandbox, iCloud/CloudKit entitlement, hardened runtime, Gatekeeper, and signing diagnosis.
- `build-macos-apps:packaging-notarization` for future archive, signing, notarization, and distribution readiness work.
- `build-macos-apps:window-management` for future macOS 15+ SwiftUI window sizing, placement, restoration, titlebar, and toolbar behavior.
- `build-macos-apps:appkit-interop` if SwiftUI cannot express a desktop behavior cleanly.
- `build-macos-apps:liquid-glass` for Liquid Glass review only if future work considers those APIs. This scaffold must not adopt Liquid Glass.
- `build-macos-apps:telemetry` for future lightweight `Logger` instrumentation and runtime verification.
- `build-macos-apps:test-triage` for triaging failing macOS tests across Xcode and SwiftPM workflows.

## Testing And Verification

This scaffold pass should verify:

- The app target builds for macOS.
- The app target builds for an iOS simulator if a suitable simulator/tooling path is available.
- Existing tests either build or are updated away from the starter `Item` model.
- The build/run script works for the macOS app.
- Coverage measurement works locally through Xcode's coverage data, for example `xcodebuild test -enableCodeCoverage YES` plus `xccov` or `llvm-cov` extraction.
- Carp is included in the coverage/tooling workflow where it fits the Swift/Xcode setup, alongside Xcode coverage output rather than replacing it blindly.
- The repo has a documented coverage threshold of 90% line coverage across the whole codebase for future implementation work.

No product behavior tests are required yet because this pass does not implement product behavior. The scaffold should still install the tooling needed to measure coverage once real behavior lands.

## Acceptance Criteria

- The starter `Item` template model and default `ContentView` shape are removed or replaced.
- The app has a clear folder structure matching the architecture above.
- SwiftData is wired with a minimal Pika-specific model.
- Design-system token files exist but do not yet contain a full component library.
- Navigation/store/service boundaries exist but remain thin.
- The project is prepared for iCloud/CloudKit without committing to the final schema.
- The app builds after the scaffold changes.
- Test and coverage commands exist and are documented.
- The coverage gate is defined as 90% line coverage across the whole codebase.
- No real Pika product screens or workflows are implemented.

## Open Decisions For The Next Pass

- Final domain model relationships for projects, buckets, time entries, fixed costs, and invoices.
- Exact CloudKit container identifier and production provisioning details.
- Which generated design variant becomes the source of truth for the first real component pass.
- Whether invoice PDF rendering is built before or after the core time-entry flow.
- Which App Intents are worth exposing after the app has real workflows.
