# Responsibility Boundary Refactor Spec (2026-04-28)

## Purpose

Prepare Pika for a batch refactor that reduces responsibility density in the largest app files without changing user-visible behavior.

This is not a redesign and not a feature project. The goal is to make the current architecture more honest: feature-level code should live in feature-level boundaries, stores should remain narrow state boundaries, models should remain data-shaped, and services should own reusable behavior that should not be duplicated inside views.

## Source Feedback

This spec operationalizes the diagnosis in:

- `docs/architecture-feedback/2026-04-28-responsibilities-per-file-debt.md`

The core finding is that Pika does not primarily suffer from folder chaos. It suffers from too many responsibilities per file.

## Target Outcome

After this refactor:

- Project workbench UI is split into named project feature components.
- Client management UI is split into named client feature components.
- Store responsibilities are separated by domain area while preserving one coherent workspace/store boundary.
- Workspace data models are separated from projections and reporting views.
- Invoice PDF responsibilities are clearer, with reusable PDF/open/export behavior available outside individual views.
- Existing behavior, tests, previews, app launch behavior, and persistence semantics remain unchanged unless a test exposes a real bug.

## Non-Goals

- Do not redesign the product UI.
- Do not change navigation behavior.
- Do not change persistence format intentionally.
- Do not rename domain concepts for taste alone.
- Do not introduce a new architecture framework.
- Do not add a dependency injection container.
- Do not rewrite the invoice PDF renderer from scratch.
- Do not migrate to a different persistence layer.
- Do not combine this with seed-data cleanup unless needed to keep tests compiling.

## Guiding Principles

- Prefer mechanical extraction before behavioral refactor.
- Preserve public behavior first; improve naming and placement second.
- Keep the app native macOS SwiftUI and MV-first.
- Views own local presentation state.
- Models and services own domain behavior.
- Stores coordinate state and persistence boundaries; they should not become domain engines.
- Shared PDF/AppKit side effects should live behind reusable services or action helpers, not copied across views.
- Each extracted file should have a single obvious reason to change.

## Proposed Destination Shape

The exact folder shape may adapt to current code, but the batch refactor should move toward:

```text
pika/
  Features/
    Projects/
    Clients/
    Invoices/
    Dashboard/
    Settings/
  Models/
    Workspace/
    Invoicing/
    Projections/
  Services/
    InvoicePDF/
  Stores/
```

Do not create empty folders. Only introduce a folder when it receives real code in this refactor.

## Batch Sequencing

### Phase 0: Baseline And Safety

User story:

As a maintainer, I want a clean behavior baseline before splitting files so that I can distinguish refactor regressions from pre-existing failures.

Acceptance criteria:

- Current git status is reviewed before editing.
- Existing untracked docs are preserved.
- Current test/build command is identified.
- A baseline build or focused test run is captured before large moves where practical.
- The refactor agent records any pre-existing failing tests instead of silently normalizing them.

Suggested verification:

- Run the smallest reliable command that compiles app and tests for this Xcode project.
- If full UI tests are too slow, record that choice and run focused unit tests plus app build.

### Phase 1: Project Workbench Extraction

Primary files:

- `pika/Shell/ProjectPlaceholderView.swift`
- Existing project-related shell views such as project list, bucket columns, entry tables, and editor sheets.

User story:

As a freelancer using Pika, I want the project workbench to behave exactly as before while its sidebar, toolbar, sheets, dialogs, and invoice actions are owned by named project feature components.

Responsibilities to separate:

- Root project workbench composition.
- Bucket sidebar and bucket selection.
- Project toolbar actions.
- Create bucket flow.
- Create fixed-cost entry flow.
- Create/finalize invoice confirmation flow.
- Project invoice open/export actions.
- Small private detail/sheet views currently hidden inside the large placeholder file.

Expected result:

- `ProjectPlaceholderView` should no longer be the main project feature module in disguise.
- A clearly named root such as `ProjectWorkbenchView` owns high-level composition.
- Supporting views live near the project feature rather than remaining buried in one large shell file.
- Any compatibility wrapper, if needed, is temporary and thin.

Acceptance criteria:

- Project selection, bucket selection, entry creation, fixed-cost creation, invoice confirmation, archive/delete flows, and PDF open/export still work.
- Existing previews either continue to compile or are replaced with equivalent previews in the new feature files.
- The root project file is materially smaller and mostly orchestration.
- No duplicated project invoice action logic is introduced.
- Naming reflects product concepts, not "placeholder" terminology.

### Phase 2: Client Feature Extraction

Primary file:

- `pika/Shell/ClientsView.swift`

User story:

As a freelancer managing clients, I want the clients screen to preserve list, detail, edit, archive, delete, and creation behavior while the code is split into small feature-owned views.

Responsibilities to separate:

- Clients root composition.
- Client list and row presentation.
- Client detail surface.
- Editable client fields.
- Client creation sheet.
- Archive/delete confirmation flows.
- Address parsing and formatting UI behavior.
- Save state and validation messaging.

Expected result:

- `ClientsView` remains a readable feature root.
- Dedicated client feature files own rows, forms, sheets, and detail surfaces.
- Domain-sensitive formatting or parsing is not duplicated in multiple views.

Acceptance criteria:

- Client creation, editing, validation, archive, restore if present, and delete behavior are unchanged.
- Empty, selected, archived, and invalid-input states still render correctly.
- Existing tests compile; add focused tests only if extraction exposes untested behavior with real risk.
- The root file has one obvious job: assemble the clients feature.

### Phase 3: Store Responsibility Split

Primary file:

- `pika/Stores/ProjectStore.swift`

User story:

As a maintainer, I want workspace/store behavior separated by responsibility so that changes to clients, projects, buckets, invoices, persistence, activity, and telemetry can be understood independently.

Responsibilities to separate:

- Workspace/store core state.
- Client mutations.
- Project mutations.
- Bucket mutations.
- Entry mutations.
- Invoice transitions.
- Draft handling.
- Validation coordination.
- Persistence load/save coordination.
- Activity logging coordination.
- Telemetry calls.
- Archive/delete rules.

Expected result:

- Keep one coherent store boundary unless the code already strongly supports a narrower split.
- Prefer responsibility-based extensions or sibling files before introducing new runtime types.
- Store API behavior remains source-compatible for views and tests where practical.
- Domain decisions become easier to locate.

Acceptance criteria:

- Existing store tests pass.
- Persistence behavior is unchanged.
- Activity log behavior is unchanged.
- Invoice status transitions are unchanged.
- Archive/delete constraints are unchanged.
- Telemetry remains lightweight and is not made noisier.
- The original large store file is materially smaller and contains core state plus high-level coordination only.

### Phase 4: Workspace Model And Projection Separation

Primary files:

- `pika/Models/WorkspaceSnapshot.swift`
- Existing projection-related files such as `WorkspaceBucketProjections`.

User story:

As a maintainer, I want core workspace data shape separated from dashboard, project detail, invoice list, normalization, and compatibility projections so that model changes do not require reading reporting and UI projection logic.

Responsibilities to separate:

- Core workspace snapshot data.
- Coding and compatibility behavior.
- Normalization behavior.
- Dashboard summary projections.
- Project detail projections.
- Bucket/entry projections.
- Invoice list projections.
- Any test/demo fixture coupling discovered during the move.

Expected result:

- Core model files contain model shape and essential model behavior.
- Projection files contain view/reporting-oriented computed shapes.
- Compatibility/coding logic is findable and isolated.
- Existing callers remain clear and source-compatible where practical.

Acceptance criteria:

- Snapshot decoding/encoding tests pass.
- Dashboard, project, bucket, and invoice projections return the same observable values as before.
- Test fixtures are not made more coupled to demo data during this refactor.
- The core snapshot file is materially smaller and easier to scan.

### Phase 5: Invoice PDF Service Boundary

Primary files:

- `pika/Services/InvoicePDFService.swift`
- `pika/Shell/ProjectPlaceholderView.swift`
- `pika/Shell/InvoicesView.swift`
- `pikaTests/InvoicePDFServiceTests.swift`

User story:

As a freelancer, I want invoice PDF generation, preview/open, and export behavior to remain reliable while PDF rendering, payload construction, and UI-triggered actions are separated into clear service boundaries.

Responsibilities to separate:

- PDF generation orchestration.
- Drawing/rendering.
- Payment QR payload construction.
- Text/layout helpers.
- File open/export actions used by views.

Expected result:

- PDF drawing can remain verbose, but the orchestration file should not own every helper.
- Shared view actions for opening/exporting PDFs should not be duplicated between project and invoice screens.
- Existing PDF tests continue to cover generated output behavior.

Acceptance criteria:

- Existing invoice PDF tests pass.
- Manual PDF open/export paths still work from project and invoice contexts.
- Payment QR payload behavior is unchanged.
- No UI view directly duplicates low-level PDF/AppKit file action code.

### Phase 6: Navigation And Shell Cleanup

Primary files:

- Remaining `pika/Shell/*.swift` files.
- Any app/root navigation files that reference moved views.

User story:

As a maintainer, I want `Shell` to represent application shell/navigation instead of being a catch-all feature folder.

Responsibilities to separate:

- App shell and top-level navigation.
- Feature roots.
- Reusable design-system components.
- Reusable support utilities.

Expected result:

- `Shell` contains shell-level composition only.
- Feature-specific code lives under `Features`.
- Existing imports and Xcode project membership are updated.

Acceptance criteria:

- App launches to the same initial UI.
- Top-level navigation still reaches dashboard, projects, clients, invoices, and settings.
- No feature-only file remains in `Shell` without a deliberate reason.

## Parallel Workstreams

These workstreams can be assigned to separate agents if file ownership is kept clear:

- Projects UI extraction: owns project feature views and any compatibility wrapper.
- Clients UI extraction: owns client feature views.
- Store split: owns store files and tests touching store behavior.
- Workspace model/projection split: owns model/projection files and snapshot tests.
- Invoice PDF boundary: owns invoice PDF service files and PDF tests.

Coordination rules:

- Do not edit the same source files concurrently.
- Share new service/type names before wiring cross-feature callers.
- Keep moves mechanical inside each workstream before making naming improvements.
- Re-run compile after each merged workstream.

## Verification Plan

Minimum verification before declaring the batch complete:

- App target builds.
- Unit tests pass or pre-existing failures are documented.
- PDF service tests pass.
- Store/domain tests pass.
- Workspace snapshot tests pass.
- Project and client flows receive at least one manual launch smoke test if UI tests are not reliable.

Manual smoke checklist:

- Launch app.
- Open Projects.
- Select project and bucket.
- Create a bucket.
- Create a fixed-cost entry.
- Start invoice confirmation flow.
- Open or export an invoice PDF.
- Open Clients.
- Create a client.
- Edit required fields.
- Archive/delete through confirmation flow.
- Open Invoices.
- Open/export an invoice PDF from the invoice list context.

## Done Definition

The refactor is complete when:

- The largest responsibility-heavy files are reduced or converted into thin roots.
- New file boundaries match product responsibilities.
- App behavior is unchanged from the user perspective.
- Tests/builds pass or any failures are explicitly documented as pre-existing.
- No temporary probes, noisy logging, or dead compatibility shims remain.
- The final diff reads like a structural refactor, not a mixed feature redesign.

## Suggested Commit Strategy

Prefer small conventional commits in this order:

1. `refactor(projects): extract project workbench views`
2. `refactor(clients): split clients feature views`
3. `refactor(stores): separate project store responsibilities`
4. `refactor(models): split workspace snapshot projections`
5. `refactor(invoices): separate invoice pdf responsibilities`
6. `refactor(shell): move feature roots out of shell`

If a phase becomes too large, split by feature component while preserving the same phase order.

## Handoff Prompt For Codex Spark

Use this prompt when handing the task to a lower-cost batch refactor agent:

> Execute the responsibility boundary refactor described in `docs/superpowers/specs/2026-04-28-responsibility-boundary-refactor.md`.
> Keep behavior unchanged. Start with baseline status/build checks, then work phase by phase.
> Prefer mechanical extraction, named feature boundaries, and focused verification after each phase.
> Preserve unrelated user changes and do not redesign UI or persistence.
> Report changed files, verification commands, and any pre-existing failures.
