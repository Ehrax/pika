# Responsibility Boundary Follow-up Spec (Wave 2)

Date: 2026-04-28
Repo: `/Users/ehrax/Projects/ehrax.dev/billbi`

## Goal

Apply a second behavior-preserving cleanup wave after the first boundary refactor, focused on:
- misplaced extensions/helpers
- model/projection logic embedded in views
- duplicated policy logic across files
- readability/discoverability for future human + agent maintenance

## Constraints

- Preserve user-visible behavior and persistence semantics.
- Prefer mechanical extraction over redesign.
- Keep source compatibility where practical.
- No architecture framework migration.

## Findings Summary

1. Shared sidebar row modifier is hidden in `Shell/ProjectBucketColumn.swift` but used cross-feature.
2. Calendar helpers are duplicated (`billbiGregorian` and `billbiStoreGregorian`) with same behavior.
3. Invoice status/tone/action policy is duplicated across `InvoicesFeatureView`, `BucketDetailWorkbench`, `ProjectWorkbenchView`, and store rules.
4. Address/payment parsing lives in feature views instead of shared support/model boundaries.
5. Duration parser is located in projection file while store depends on it.
6. Large feature files still contain mixed orchestration + business/presentation policy.

## Work Packets

### Packet W2-1: Shared UI/Support helper extraction

Objective:
- Move cross-feature UI/support helpers into discoverable shared files.

Owned files:
- `billbi/Shell/ProjectBucketColumn.swift`
- `billbi/DesignSystem/BillbiSidebarRowStyle.swift` (new)
- `billbi/Features/Settings/SettingsFeatureView.swift`
- `billbi/Features/Clients/ClientsFeatureView.swift`
- `billbi/Support/BillingTextComponents.swift` (new)
- `billbi/Features/Invoices/InvoicesFeatureView.swift`
- `billbi/Services/InvoicePDF/MacPDFDocumentView.swift` (new)

Dependencies:
- none

Invariants:
- sidebar row visuals unchanged
- settings/client address behavior unchanged
- invoice preview rendering unchanged

### Packet W2-2: Domain/policy extraction and deduplication

Objective:
- Centralize invoice action/presentation rules and shared domain helpers.

Owned files:
- `billbi/Stores/WorkspaceStore+BucketAndInvoiceRules.swift`
- `billbi/Models/Workspace/WorkspaceSnapshot.swift`
- `billbi/Models/Projections/WorkspaceBucketProjections.swift`
- `billbi/Features/Projects/ProjectWorkbenchView.swift`
- `billbi/Features/Invoices/InvoicesFeatureView.swift`
- `billbi/Shell/BucketDetailWorkbench.swift`
- `billbi/Support/BillbiCalendar.swift` (new)
- `billbi/Support/WorkspaceEntryDurationParser.swift` (new)
- `billbi/Models/Invoicing/InvoiceWorkflowPolicy.swift` (new)

Dependencies:
- may depend on W2-1 if touching same invoice view sections; merge carefully

Invariants:
- invoice state transition behavior unchanged
- overdue/status badge behavior unchanged
- entry parsing behavior unchanged

### Packet W2-3: Reporting/projection extraction prep (non-breaking)

Objective:
- Prepare clean seams for moving dashboard/reporting logic out of views.

Owned files:
- `billbi/Features/Dashboard/DashboardFeatureView.swift`
- `billbi/Models/Projections/DashboardRevenueProjection.swift` (new)

Dependencies:
- none

Invariants:
- chart/range behavior and labels unchanged

## Execution Order

1. W2-1 and W2-3 in parallel.
2. W2-2 after W2-1 merge for any `InvoicesFeatureView` overlap.
3. Final integration cleanup for naming and dead private helpers.

## Verification Gates

Minimum:
- app compile check (`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`)
- unit tests for projections/parsers/policies where touched (if environment permits)

Smoke checklist:
- open project workbench and invoice actions
- open invoice list and PDF preview
- edit settings address + payment details
- edit/create client with address fields

## Done Definition

- Shared concepts have one clear owner file.
- Feature files become more orchestration-oriented.
- No duplicated invoice/presentation policy across multiple private extensions.
- Behavior parity maintained.
