# Billbi TODOs

This list tracks the remaining work from `docs/design-proposal/billbi-mac-first-app-handover-spec.md` after the current Mac-first implementation pass. Keep gates lightweight for SwiftUI-only visual changes; use focused tests for business/domain behavior.

## Mac App: Functional Completion

- [ ] Add edit support for time entries.
- [ ] Add delete support for time entries.
- [ ] Add edit support for fixed costs.
- [ ] Add delete support for fixed costs.
- [ ] Add bucket rename/edit support.
- [ ] Add bucket archive or remove flow, with finalized invoice safety rules.
- [ ] Allow bucket rate edits while preserving finalized invoice snapshots.
- [ ] Finish invoice actions in the invoice detail view, including cancel where valid.
- [ ] Improve invoice metadata and activity presentation around the PDF preview.
- [ ] Make dashboard revenue history derive from real invoice data.
- [ ] Replace hard-coded dashboard comparison copy with a calculated comparison, or remove it.
- [ ] Add search or command-style affordance for Mac workflows.
- [ ] Review keyboard shortcuts for entry capture, ready flow, invoice actions, and search.

## PDF And Invoice Output

- [ ] Decide whether the first invoice template should stay native-rendered or move behind a more replaceable template boundary.
- [ ] Persist PDF render records or exported PDF paths where useful.
- [ ] Confirm PDF includes business profile, client address, invoice number, issue/due dates, project/bucket context, line items, subtotal, tax/VAT note, total, and payment details.
- [ ] Add focused PDF/export tests for the behavior that is not already covered.
- [ ] Verify PDF open/export from both bucket context and invoice list context.

## Clients And Projects

- [ ] Add client archive support if it still fits the product model.
- [ ] Decide whether client deletion is needed, or explicitly defer it.
- [ ] Keep project archive/restore behavior aligned with invoice and activity history.
- [ ] Re-check project card/list sizing and selection styling after the sidebar width work settles.

## Data, Persistence, And Domain Rules

- [ ] Review invoice snapshot behavior so later client, project, bucket, rate, or entry edits do not rewrite historical invoices.
- [ ] Review overdue behavior so it stays derived from due date and unpaid invoice status.
- [ ] Add focused tests for any missing status transitions.
- [ ] Add focused tests for edit/delete behavior once implemented.
- [ ] Split sample/seed data out of large mixed files if it keeps slowing implementation down.

## Design And Runtime Verification

- [ ] Run one clean Mac end-to-end verification flow: create client, create project, create bucket, add entries, add fixed cost, mark ready, finalize invoice, export/open PDF, mark sent, mark paid.
- [ ] Capture Mac screenshots for dashboard, projects, bucket detail, invoice detail, clients, and settings.
- [ ] Compare Mac screenshots against `docs/design-proposal` and `docs/design-proposal/native-design-manifest.json`.
- [ ] Verify where Liquid Glass or native materials are used, and where plain surfaces are intentional.
- [ ] Keep the second/sidebar panes native and resizable; avoid custom split handles unless absolutely necessary.
- [ ] Revisit visual polish for invoices, clients, buckets, and dashboard after functional gaps close.

## Refactor And Simplify

- [ ] Run a final review-and-simplify pass after the Mac functional loop is real.
- [ ] Split oversized views only where it reduces real complexity.
- [ ] Keep reusable design-system additions narrow and justified by duplication.
- [ ] Remove noisy temporary telemetry, keeping useful product/debug logs.

## iOS And iPadOS Companion

- [ ] Start iOS/iPadOS only after the Mac app is usable end to end.
- [ ] Discover a booted iOS simulator before iOS runtime verification.
- [ ] Build Today/dashboard triage for iPhone.
- [ ] Build stacked Projects and Buckets navigation for iPhone.
- [ ] Build bucket detail with entries, totals, and add-entry sheet.
- [ ] Build ready-to-invoice review and invoice status actions.
- [ ] Build PDF open support for invoice detail.
- [ ] Capture iPhone screenshots and compare against the proposal once iOS work begins.
