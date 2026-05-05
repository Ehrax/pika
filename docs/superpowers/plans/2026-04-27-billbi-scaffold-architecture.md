# Billbi Scaffold Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the starter SwiftData template with a compile-safe Billbi scaffold, scripts, coverage gate, and minimal architecture boundaries only.

**Architecture:** Keep the app MV-first with `App/` owning launch and dependency injection, `Shell/` owning a tiny root view, and future behavior reserved behind thin `Navigation/`, `Stores/`, `Services/`, `DesignSystem/`, `Models/`, and `Support/` boundaries. SwiftData is wired with one minimal Billbi-named model and no real invoicing/product workflows.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, Xcode project with file-system-synchronized groups, shell scripts for build/test/coverage, Xcode `xccov` coverage output.

---

## File Structure

- Delete: `billbi/ContentView.swift`
- Delete: `billbi/Item.swift`
- Delete: `billbi/billbiApp.swift`
- Create: `billbi/App/BillbiApp.swift` for `@main`, `WindowGroup`, and SwiftData root container.
- Create: `billbi/App/AppDependencyGraph.swift` for one environment wiring modifier.
- Create: `billbi/Models/ProjectRecord.swift` for the only persisted scaffold model.
- Create: `billbi/Shell/RootView.swift` for a minimal launchable placeholder.
- Create: `billbi/DesignSystem/BillbiColor.swift`, `BillbiTypography.swift`, `BillbiSpacing.swift`, `BillbiRadius.swift`, `BillbiStatusTone.swift` for tokens only.
- Create: `billbi/Navigation/AppRoute.swift`, `SheetDestination.swift`, `AppRouter.swift` for value-based routing state.
- Create: `billbi/Stores/ProjectStore.swift` for a small project store protocol/shell.
- Create: `billbi/Services/AppSettings.swift`, `InvoicePDFService.swift` for environment-accessible service boundaries and explicit unavailable PDF placeholder behavior.
- Create: `billbi/Support/MoneyFormatting.swift`, `PreviewSupport.swift` for small executable helpers.
- Modify: `billbiTests/billbiTests.swift` into focused scaffold behavior tests.
- Create: `script/build_and_run.sh`, `script/test.sh`, `script/test_ios.sh`, `script/coverage.sh`.
- Create: `.codex/environments/environment.toml`.
- Create: `docs/tooling.md`.

## Task 1: App Root, SwiftData Model, And Minimal Shell

**Files:**
- Delete: `billbi/ContentView.swift`
- Delete: `billbi/Item.swift`
- Delete: `billbi/billbiApp.swift`
- Create: `billbi/App/BillbiApp.swift`
- Create: `billbi/App/AppDependencyGraph.swift`
- Create: `billbi/Models/ProjectRecord.swift`
- Create: `billbi/Shell/RootView.swift`
- Test: `billbiTests/billbiTests.swift`

- [ ] **Step 1: Write the failing model/container test**

```swift
import Foundation
import SwiftData
import Testing
@testable import billbi

struct BillbiScaffoldTests {
    @Test func projectRecordDefaultsAreBillbiSpecificAndFlexible() {
        let createdAt = Date(timeIntervalSince1970: 1_776_000_000)
        let project = ProjectRecord(title: "Client work", createdAt: createdAt)

        #expect(project.title == "Client work")
        #expect(project.createdAt == createdAt)
        #expect(project.isArchived == false)
        #expect(project.id.uuidString.isEmpty == false)
    }

    @Test func appModelContainerCanBeCreatedInMemory() throws {
        let container = try BillbiApp.makeModelContainer(inMemory: true)

        let context = ModelContext(container)
        let project = ProjectRecord(title: "Preview project")
        context.insert(project)
        try context.save()

        let records = try context.fetch(FetchDescriptor<ProjectRecord>())
        #expect(records.map(\.title) == ["Preview project"])
    }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run: `xcodebuild test -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' -only-testing:billbiTests CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because `ProjectRecord` and `BillbiApp.makeModelContainer(inMemory:)` do not exist.

- [ ] **Step 3: Implement the minimal app scaffold**

Create `ProjectRecord` with `@Model`, `id`, `title`, `createdAt`, and `isArchived`.

Create `BillbiApp` with `@main`, static `makeModelContainer(inMemory:)`, `WindowGroup { RootView() }`, `.modelContainer(sharedModelContainer)`, and `.billbiDependencies()`.

Create `RootView` as a small placeholder using system fonts/colors only. Text may say `Billbi` and `Scaffold ready`; do not add product lists, dashboards, invoices, buckets, sidebars, or real workflows.

Create `AppDependencyGraph` as a `ViewModifier` that injects `AppRouter`, `AppSettings`, a `ProjectStore`, and `InvoicePDFService` environment values once those types exist in Task 3; for Task 1 it may be a no-op modifier so the app compiles.

- [ ] **Step 4: Run the test and verify GREEN**

Run: `xcodebuild test -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' -only-testing:billbiTests CODE_SIGNING_ALLOWED=NO`

Expected: PASS for the unit test target.

## Task 2: Design Tokens And Support Helpers

**Files:**
- Create: `billbi/DesignSystem/BillbiColor.swift`
- Create: `billbi/DesignSystem/BillbiTypography.swift`
- Create: `billbi/DesignSystem/BillbiSpacing.swift`
- Create: `billbi/DesignSystem/BillbiRadius.swift`
- Create: `billbi/DesignSystem/BillbiStatusTone.swift`
- Create: `billbi/Support/MoneyFormatting.swift`
- Create: `billbi/Support/PreviewSupport.swift`
- Test: `billbiTests/billbiTests.swift`

- [ ] **Step 1: Write failing tests for executable token/helper behavior**

Add tests that assert `BillbiSpacing.md == 16`, `BillbiRadius.lg == 8`, `BillbiStatusTone.success.accessibilityLabel == "Success"`, and `MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX")).string(fromMinorUnits: 12345) == "EUR 123.45"`.

- [ ] **Step 2: Run the tests and verify RED**

Run: `xcodebuild test -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' -only-testing:billbiTests CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because the token/helper types do not exist.

- [ ] **Step 3: Implement minimal tokens and helpers**

Use the generated hi-fi token values from `/Users/ehrax/Projects/ehrax.dev/billbi/docs/design-proposal/hifi-tokens.jsx` as semantic constants, translated to SwiftUI `Color`, `Font`, `CGFloat`, and simple tone metadata. Use Apple system fonts only. Keep tokens as tiny helpers, not components.

Implement `MoneyFormatting` as a small value type backed by `NumberFormatter`; do not add invoice, totals, tax, or billing behavior.

Implement `PreviewSupport` only for an in-memory `ModelContainer` helper for `ProjectRecord`.

- [ ] **Step 4: Run the tests and verify GREEN**

Run: `xcodebuild test -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' -only-testing:billbiTests CODE_SIGNING_ALLOWED=NO`

Expected: PASS for all unit tests.

## Task 3: Navigation, Store, Service, And Dependency Boundaries

**Files:**
- Create: `billbi/Navigation/AppRoute.swift`
- Create: `billbi/Navigation/SheetDestination.swift`
- Create: `billbi/Navigation/AppRouter.swift`
- Create: `billbi/Stores/ProjectStore.swift`
- Create: `billbi/Services/AppSettings.swift`
- Create: `billbi/Services/InvoicePDFService.swift`
- Modify: `billbi/App/AppDependencyGraph.swift`
- Test: `billbiTests/billbiTests.swift`

- [ ] **Step 1: Write failing tests for thin executable behavior**

Add tests that assert `AppRoute.project(id:)` and `SheetDestination.projectEditor(id:)` are `Hashable`/`Identifiable` value state, `AppRouter.present(sheet:)` and `dismissSheet()` mutate only sheet state, `AppSettings.defaultPaymentTermsDays == 14`, and `InvoicePDFService.placeholder().renderDraftPDF()` throws `InvoicePDFService.Error.notImplemented`.

- [ ] **Step 2: Run the tests and verify RED**

Run: `xcodebuild test -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' -only-testing:billbiTests CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because the boundary types do not exist.

- [ ] **Step 3: Implement the thin boundaries**

Use `@Observable` classes for root-owned shared app state where appropriate. Keep `AppRouter` to `path`, `sheet`, `push`, `present`, and `dismissSheet`.

Define `ProjectStore` as a small protocol with no business workflow and a `NoopProjectStore` for dependency graph wiring.

Define `InvoicePDFService` as an explicit placeholder service that throws `notImplemented`; do not render HTML, PDFs, invoice numbers, or billing data.

Update `AppDependencyGraph` to inject real default instances through environment values.

- [ ] **Step 4: Run the tests and verify GREEN**

Run: `xcodebuild test -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' -only-testing:billbiTests CODE_SIGNING_ALLOWED=NO`

Expected: PASS for all unit tests.

## Task 4: Build, Test, Coverage, And Codex Run Tooling

**Files:**
- Create: `script/build_and_run.sh`
- Create: `script/test.sh`
- Create: `script/test_ios.sh`
- Create: `script/coverage.sh`
- Create: `.codex/environments/environment.toml`
- Create: `docs/tooling.md`

- [ ] **Step 1: Add tooling scripts**

`script/build_and_run.sh` should kill only a running copy launched from the project-local DerivedData path, build the macOS app with `xcodebuild build -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`, locate the built `.app`, launch it with `/usr/bin/open -n`, and support `--verify` by checking the built executable path.

`script/test.sh` should run unit tests with coverage enabled: `xcodebuild test -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' -only-testing:billbiTests -enableCodeCoverage YES CODE_SIGNING_ALLOWED=NO`.

`script/test_ios.sh` should run the unit tests against an automatically discovered iPhone simulator destination with an `IOS_DESTINATION` override.

`script/coverage.sh` should run tests into a deterministic `.build/coverage/BillbiCoverage.xcresult`, extract line coverage with `xcrun xccov view --report --json`, print raw Xcode coverage and the testable production logic coverage percentage, and exit non-zero when the testable production logic line coverage is below `90`.

- [ ] **Step 2: Add Codex environment and docs**

Create `.codex/environments/environment.toml` with a Run action that executes `./script/build_and_run.sh --verify`.

Create `docs/tooling.md` documenting macOS build/run, unit tests, coverage threshold, iOS simulator test command, and the CRAP metrics deferral.

- [ ] **Step 3: Run script syntax checks**

Run: `bash -n script/build_and_run.sh script/test.sh script/test_ios.sh script/coverage.sh`

Expected: PASS.

## Task 5: Final Verification And Scope Review

**Files:**
- All changed files.

- [ ] **Step 1: Verify no starter template references remain**

Run: `rg "ContentView|Item|Add Item|timestamp|Select an item" billbi billbiTests`

Expected: no output.

- [ ] **Step 2: Verify macOS build**

Run: `xcodebuild build -project billbi.xcodeproj -scheme billbi -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Verify tests with coverage**

Run: `./script/test.sh`

Expected: unit tests pass with code coverage enabled.

- [ ] **Step 4: Verify coverage threshold command**

Run: `./script/coverage.sh`

Expected: prints whole-codebase line coverage and reports whether it meets the 90% threshold. If scaffold-only untested SwiftUI or generated paths keep it below 90%, report the exact percentage and keep the command/gate working.

- [ ] **Step 5: Verify iOS simulator build if available**

Run: `xcodebuild build -project billbi.xcodeproj -scheme billbi -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' CODE_SIGNING_ALLOWED=NO`

Expected: build succeeds, or the exact simulator/tooling blocker is reported.

- [ ] **Step 6: Verify metrics deferral**

Run: `rg -n "Metrics|CRAP" docs/tooling.md`

Expected: docs clearly state that CRAP-style metrics are intentionally deferred until the app has enough executable logic and coverage data for the metric to be meaningful.

- [ ] **Step 7: Run review-swarm on final diff**

Scope: `git diff main...HEAD`.

Expected: aggregate material findings only, fix any material scaffold issues, and report anything intentionally deferred.

## Self-Review

- Spec coverage: app, design system, navigation, model, stores, services, shell, support, scripts, coverage, and documentation all map to tasks.
- Scope guard: no project, bucket, invoice, dashboard, settings, PDF rendering, App Intents, widgets, Liquid Glass, or real product workflow is planned.
- TDD guard: executable production logic is covered by RED/GREEN unit test steps; configuration-only and script/doc scaffolding are handled as narrow scaffold exceptions with syntax/verification commands.
