# Pika Mac-First App Handover Spec

Date: 2026-04-27

## Purpose

Build Pika as a ready-to-use SwiftUI invoicing app for freelance work, with macOS as the primary product surface and iOS/iPadOS as companion capture and review surfaces. The scaffold is expected to exist before implementation begins; this document defines what the implementation workflow should build once that scaffold is ready.

This spec is intentionally Mac-first. The Mac app must become usable end to end before iOS polish is allowed to consume meaningful time.

## Source Materials

Use these files as the design source of truth:

- `docs/design-proposal/Pika Hi-Fi.html`
- `docs/design-proposal/Pika Wireframes.html`
- `docs/design-proposal/Pika Wireframes-print.html`
- `docs/design-proposal/hifi-mac.jsx`
- `docs/design-proposal/hifi-iphone.jsx`
- `docs/design-proposal/hifi-atoms.jsx`
- `docs/design-proposal/hifi-tokens.jsx`
- `docs/design-proposal/storyboard-mac-a.jsx`
- `docs/design-proposal/storyboard-mac-b.jsx`
- `docs/design-proposal/storyboard-phone.jsx`
- `docs/design-proposal/screenshots/`

The JSX and screenshots describe strong product structure and visual language, but they are React/web artifacts. The implementation must translate them into native Apple platform UI, not copy web layout mechanically.

## Design Translation Manifest

Before implementation tasks start, dispatch a dedicated design-translation subagent to create a native design mapping manifest at:

`docs/design-proposal/native-design-manifest.json`

This subagent should be read/write only for the manifest file and read-only for the proposal assets. It should not touch app source. Give it `AGENTS.md`, this spec, and the proposal file list. Its job is to interpret the design source into native Apple UI decisions before implementation agents begin.

The manifest must interpret the React/web proposal into native Apple design decisions. It should include:

- Each proposal screen and its matching SwiftUI destination.
- Each reusable visual primitive from `hifi-atoms.jsx` and the native replacement.
- Liquid Glass candidates, including why each element should or should not use glass.
- Elements that should become native controls, such as `NavigationSplitView`, `NavigationStack`, sheets, inspectors, toolbars, sidebars, tables, forms, popovers, menus, segmented controls, and standard buttons.
- Elements that should stay plain instead of glass, especially dense tables, long invoice content, editable form rows, and anything where translucency harms legibility.
- Screenshot verification targets for macOS first and iOS later.
- Notes on deviations from the screenshots where Apple design language or Liquid Glass requires a better native treatment.

The manifest is a hard workflow gate. The orchestrator should not start app implementation until the design-translation subagent has produced this file and the orchestrator has reviewed it for obvious omissions.

## Product Target

Pika must be usable immediately for a freelancer to:

1. Create and manage clients.
2. Create and manage projects.
3. Create buckets under projects.
4. Log billable and non-billable time entries.
5. Add fixed cost entries.
6. Mark buckets ready for invoicing.
7. Create finalized invoices from ready buckets.
8. Generate and open/export a PDF invoice.
9. Mark invoices as finalized, sent, paid, overdue, or cancelled where appropriate.
10. Review dashboard totals, outstanding work, overdue invoices, and recent activity.
11. Configure basic business profile, invoice numbering, currency, payment details, and invoice note.

The first invoice template must be deliberately simple. It can be HTML-backed or otherwise template-driven, but it must stay easy to replace. Do not spend the first implementation pass on elaborate template design.

## Mac-First Experience

The macOS app is the primary app.

Required Mac screens and flows:

- Dashboard: outstanding, overdue, ready to invoice, this month, needs-attention list, recent activity, simple revenue history.
- Projects: active and archived projects, project totals, ready/overdue indicators.
- Project detail: buckets list, bucket states, project/client metadata.
- Bucket detail: time entries, fixed costs, totals, non-billable tracking, mark-ready action.
- Inline entry capture: fast keyboard-first entry creation from Mac, inspired by `HiFi_MacA3`.
- Invoice confirmation: recipient, invoice number, issue date, due date, currency, note, totals.
- Invoice detail: metadata column, activity, PDF preview/open/export, mark sent, mark paid.
- Clients: basic CRUD, billing address, email, default payment terms.
- Settings: business profile, invoice prefix/numbering, payment details, default currency, default tax/VAT note.

Mac design requirements:

- Prefer native macOS structure: `NavigationSplitView`, sidebar, toolbar actions, keyboard-first row editing, sheets, popovers, and window-aware layout.
- Preserve the dense, calm, professional visual language from the proposal.
- Adapt the flat card-heavy web look into SwiftUI surfaces with appropriate Liquid Glass only where it improves hierarchy.
- Use Liquid Glass for high-level app chrome, toolbars, transient sheets, selected navigation surfaces, and appropriate floating controls.
- Avoid Liquid Glass on dense data tables, invoice previews, long text forms, totals rows, or editable controls where legibility matters more than material.
- Use native symbols/icons where possible.
- Keep Mac power workflows fast: keyboard entry, command search or command-like affordances where feasible, and minimal modal friction.

## iOS and iPadOS Companion Scope

iOS/iPadOS follow after the Mac loop is usable.

Required companion flows:

- Today/dashboard triage with outstanding, overdue, ready-to-invoice, and quick-log affordances.
- Projects stacked navigation.
- Buckets stacked navigation.
- Bucket detail with entries and totals.
- Add entry sheet.
- Ready-to-invoice view.
- Invoice detail actions: open PDF, mark sent, and mark paid. Reminder/email automation may be deferred unless the scaffold already provides a simple mail handoff.

iPhone should use `NavigationStack`, native sheets, large titles, safe areas, dynamic type, and platform gestures. iPad may adapt toward a split view, but Mac remains first priority.

## Data Model

The scaffold may choose concrete persistence, but the app must support these durable concepts:

- Business profile: legal/display name, address, email, tax/VAT note, payment details.
- Client: name, address, email, default payment terms, archive state.
- Project: name, client, rate defaults, currency, archive state, started date.
- Bucket: project, name, billing mode, hourly rate or unit rate, status, ready/finalized links.
- Time entry: bucket, date, start/end or duration, description, billable flag, rate snapshot.
- Fixed cost entry: bucket, date, description, quantity, unit price, billable flag.
- Invoice: number, client snapshot, project/bucket snapshots, line item snapshots, issue date, due date, currency, status, PDF path or render record.
- Activity event: user-visible event history and debug-friendly telemetry correlation where useful.

Invoice finalization must snapshot invoice data so later project, client, rate, or entry edits do not rewrite historical invoices.

## Status Rules

Use simple statuses:

- Bucket: open, ready, invoiced/finalized, archived.
- Invoice: draft only if needed internally, finalized, sent, paid, overdue, cancelled.
- Entry: editable until its bucket is finalized into an invoice; finalized invoice line snapshots are not editable through the bucket entry UI.

Overdue status should be derived from due date plus unpaid/sent/finalized state, not stored as a fragile manual flag unless the model has a clear reason.

## Invoice Output

PDF/export is required for ready-to-use.

Implementation constraints:

- Keep the first template simple, legible, and fast to build.
- Prefer a replaceable template boundary, such as simple HTML rendered to PDF or a small native renderer.
- Include business profile, client address, invoice number, issue/due dates, project/bucket context, line items, subtotal, tax/VAT note, total, and payment details.
- Opening/exporting the PDF must work in the Mac app.
- Do not over-design multiple templates, advanced branding, tax systems, or localization in the first pass.

## Telemetry

Add useful lightweight telemetry early. Use `Logger` / `os.Logger` or the project logging helper.

Required telemetry examples:

- App launch and selected platform surface.
- Dashboard loaded with counts.
- Project created/updated/archived.
- Bucket created/marked ready/finalized.
- Time entry/fixed cost created.
- Invoice created/finalized.
- PDF rendered/opened/exported.
- Invoice marked sent/paid/cancelled.
- Verification-only debug logs that prove important UI actions fired.

Remove noisy temporary probes before finishing. Keep stable product/debug instrumentation.

## Testing Gates

Use TDD. This requirement is repeated here even though it also appears in `AGENTS.md`.

Expected gates:

- Write a failing test before implementing behavior.
- Verify the failure is for the right reason.
- Implement the smallest useful change.
- Refactor only while tests are green.
- Cover domain rules, totals, status transitions, snapshot finalization, persistence boundaries, and PDF/export behavior.
- Add UI/launch tests where they prove user-visible behavior.
- Use CRAP metrics as a signal for changed code. Improve risky, complex, under-covered areas; do not chase numbers mechanically.

## Runtime Verification Gates

Compile success is not enough.

Mac verification is first priority:

1. Build and launch the macOS app.
2. Add telemetry if runtime visibility is missing.
3. Capture screenshots of the running app.
4. Compare screenshots against the Mac design proposal and `native-design-manifest.json`.
5. Explicitly inspect which areas became Liquid Glass, which stayed plain, and whether that matches the manifest.
6. Fix obvious visual, interaction, or native-platform mismatches before moving on.

iOS verification is required when iOS work begins:

1. Discover a booted simulator.
2. If no iOS simulator is booted, stop and tell the user exactly that a booted simulator is required.
3. Build and run on the booted simulator.
4. Capture screenshots and compare against iPhone proposal screens.
5. Use logs and UI inspection to verify interactions.

Hard gate: if the required runtime environment is unavailable, the agent must say so and stop that verification path instead of pretending screenshots or UI checks happened.

## Required Skills Inventory

The orchestrator must list and use relevant skills instead of relying on memory.

Build macOS Apps skills:

- `build-macos-apps:appkit-interop`
- `build-macos-apps:build-run-debug`
- `build-macos-apps:liquid-glass`
- `build-macos-apps:packaging-notarization`
- `build-macos-apps:signing-entitlements`
- `build-macos-apps:swiftpm-macos`
- `build-macos-apps:swiftui-patterns`
- `build-macos-apps:telemetry`
- `build-macos-apps:test-triage`
- `build-macos-apps:view-refactor`
- `build-macos-apps:window-management`

Build iOS Apps skills:

- `build-ios-apps:ios-app-intents`
- `build-ios-apps:ios-debugger-agent`
- `build-ios-apps:ios-ettrace-performance`
- `build-ios-apps:ios-memgraph-leaks`
- `build-ios-apps:swiftui-liquid-glass`
- `build-ios-apps:swiftui-performance-audit`
- `build-ios-apps:swiftui-ui-patterns`
- `build-ios-apps:swiftui-view-refactor`

Workflow skills:

- `subagent-driven-development`
- `review-and-simplify-changes`
- `test-driven-development`
- `verification-before-completion`
- `commit`

Use `build-macos-apps:build-run-debug`, `build-macos-apps:telemetry`, and `build-macos-apps:liquid-glass` as core Mac workflow skills. Use `build-ios-apps:ios-debugger-agent` as the core iOS runtime verification skill once iOS work begins.

## Orchestration Workflow

Use an orchestrator approach. The main agent coordinates the workflow, delegates focused tasks, reviews outputs, enforces gates, integrates results, and communicates status. Subagents do the scoped design translation, implementation, and review work on the orchestrator's behalf.

1. Read `AGENTS.md`.
2. Read this spec.
3. Read the design proposal files listed above.
4. Dispatch a dedicated design-translation subagent to create `docs/design-proposal/native-design-manifest.json`.
5. Review the manifest as the first hard gate and fix omissions before implementation starts.
6. Produce a Mac-first implementation task breakdown from this spec and the manifest.
7. Execute with `subagent-driven-development`.
8. Give each implementer a narrow task, relevant spec excerpts, manifest excerpts, and explicit test requirements.
9. Require TDD for each behavior task.
10. Require telemetry when implementing runtime behavior.
11. After each task, run spec compliance review.
12. After spec compliance passes, run code quality review.
13. Commit meaningful verified increments.
14. Run Mac build/run/debug/screenshot verification before claiming the Mac app is usable.
15. Only then proceed to iOS/iPadOS companion work.
16. End with `review-and-simplify-changes`.

Implementation agents must not run broad, unrelated refactors. Keep the app small, native, testable, and ready to grow.

## Completion Criteria

The work is complete when:

- The Mac app can be used end to end for real freelance invoicing.
- Basic iOS/iPadOS companion flows exist or are explicitly deferred after Mac completion with a clear reason.
- Tests cover the important domain rules and changed code risk.
- CRAP-risky changed code has been reviewed and improved where justified.
- Telemetry proves key flows during runtime verification.
- Mac screenshots have been captured and compared against the design proposal and Liquid Glass manifest.
- iOS simulator verification has run if iOS work was implemented, or the agent clearly reported that no booted simulator was available.
- The invoice PDF/export path works with a simple replaceable template.
- Final review/simplify pass is complete.
