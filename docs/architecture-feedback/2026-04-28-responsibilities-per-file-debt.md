# Architecture Feedback: Responsibilities Per File Debt (2026-04-28)

## Summary

The main architectural debt is not folder chaos. The current folder layout is usable.
The core issue is **too many responsibilities concentrated in single files**: several files are effectively feature modules in disguise.

## Biggest Debt

1. `billbi/Stores/ProjectStore.swift` (around 1,199 lines)
- Main architectural pressure point.
- Currently owns drafts, validation, mutations, persistence, activity logging, invoice transitions, archive/delete rules, and telemetry calls.
- Drift: this violates the intended "small store boundary" and behaves like a god object.

2. `billbi/Models/WorkspaceSnapshot.swift` (around 1,076 lines)
- Too broad in responsibility.
- Mixes core data models with normalization, dashboard summaries, project detail projections, invoice list projections, and compatibility/coding logic.
- Drift: data shape and projection/reporting logic are co-located.

3. `billbi/Shell/ProjectPlaceholderView.swift` (around 967 lines)
- Biggest SwiftUI composition debt.
- Owns split layout, bucket selection, toolbar actions, sheets, dialogs, invoice finalization, PDF open/export, and multiple private sheet/detail views.
- Drift: no longer a placeholder; effectively the project workbench feature.

4. `billbi/Shell/ClientsView.swift` (around 11+ top-level sections, large file)
- Contains list, creation sheet, row, detail surface, editable fields, archive/delete workflows, address parsing, and save state.
- Drift: should be a small root view plus dedicated feature files.

5. `billbi/Services/InvoicePDFService.swift` (around 727 lines)
- Length is less alarming because PDF drawing is verbose by nature.
- Still likely benefits from separation of orchestration, rendering, payload, and layout/text helpers.

## Where Current Code Drifts From Architecture Guidance

Project docs describe MV-first direction:
- views own local presentation state,
- shared services live in environment,
- domain behavior belongs in models/services,
- stores remain boundaries.

Observed drift:
- `ProjectStore` is no longer a boundary; it combines domain engine + persistence + telemetry.
- `WorkspaceSnapshot` mixes model shape with view projections and dashboard reporting.
- `Shell/` currently acts like `Features/` (17 Swift files, ~5,536 lines).
- AppKit/PDF actions duplicated in views (`ProjectPlaceholderView` and `InvoicesView`).

## Suggested Folder Direction

Do not create random new folders. Promote implicit modules into explicit feature boundaries.

```text
billbi/
  App/
  DesignSystem/
  Models/
    Workspace/
    Invoicing/
    Projections/
  Stores/
    WorkspaceStore.swift
    WorkspaceStore+Clients.swift
    WorkspaceStore+Projects.swift
    WorkspaceStore+Buckets.swift
    WorkspaceStore+Invoices.swift
    WorkspaceStore+Persistence.swift
  Services/
    InvoicePDF/
      InvoicePDFService.swift
      InvoicePDFRenderer.swift
      PaymentQRCodePayload.swift
      PDFTextDrawing.swift
  Features/
    Dashboard/
    Projects/
    Clients/
    Invoices/
    Settings/
  Navigation/
  Support/
```

## Best First Refactor

Start with `billbi/Shell/ProjectPlaceholderView.swift`.
- Rename/split toward `Features/Projects/ProjectWorkbenchView.swift`.
- Extract:
  - `ProjectBucketSidebarView`
  - `ProjectToolbar`
  - `CreateBucketSheet`
  - `CreateFixedCostSheet`
  - `CreateInvoiceConfirmationSheet`
  - `ProjectInvoiceActions` or `InvoicePDFActionService`

Then tackle `billbi/Stores/ProjectStore.swift`.
- First split with extensions by responsibility, no behavior change.
- This yields immediate clarity with lower refactor risk.

## Verdict

Largest technical debt is **not too many files**.
It is **too many responsibilities per file**.

Current folder structure is a decent base. Next move is to make feature boundaries explicit and honest.
