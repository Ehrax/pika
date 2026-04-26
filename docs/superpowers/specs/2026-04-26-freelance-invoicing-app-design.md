# Freelance Invoicing App Design

## Summary

Build a private multiplatform SwiftUI app for ehrax.dev that feels like Apple Notes, but stores structured billing data. The app helps track manual working hours and fixed costs per billable scope, generate simple A4 invoice PDFs, and track what has been sent, paid, or is overdue.

The product principle is: capture very little during work, automate the invoice paperwork later.

## Goals

- Support iOS, macOS, and iPad from one shared SwiftUI codebase.
- Use an Apple Notes-like layout and interaction model on each platform.
- Track manual time entries inside billable buckets.
- Track fixed costs inside the same buckets.
- Calculate hours, totals, outstanding revenue, overdue revenue, and monthly revenue.
- Generate simple A4 invoice PDFs from bundled HTML templates.
- Support a Swiss client invoiced in EUR first.
- Keep German Kleinunternehmer invoice notes configurable for German invoice profiles.
- Sync privately across the owner's Apple devices through iCloud.

## Non-Goals for V1

- Live timers.
- Multi-user sharing or client portals.
- Search and advanced filtering.
- Currency conversion or non-EUR invoice totals.
- Bank sync, automatic payment detection, or accounting exports.
- Editable invoice template designer.
- Importing existing Apple Notes data.
- AI-generated descriptions as a required V1 feature.

## Core Model

The app uses this hierarchy:

```text
Project -> Bucket -> Time Entries / Fixed Costs -> Invoice Draft -> Finalized Invoice
```

### Project

A project represents the client/work context, for example `bikepark-thunersee`.

Fields:

- emoji
- title
- invoice recipient/legal client details
- notes
- active or archived state

### Bucket

A bucket represents a billable scope, for example `MVP`, `Maintenance`, `Customer-facing dashboard`, or `Infra fixed costs`.

Fields:

- emoji
- title
- hourly rate in EUR
- lifecycle: `active`, `ready`, `invoiced`, `archived`
- time entries
- fixed costs

Bucket rates are live until invoicing. Changing the bucket hourly rate updates totals for all unlocked, uninvoiced time entries in that bucket. Finalized invoices snapshot the rate and totals.

### Time Entry

A time entry is manually added inside a bucket.

Fields:

- date
- start time
- end time
- calculated duration
- billable flag, default true
- optional note
- invoice lock/reference once finalized

The add flow defaults to the current bucket, today's date, the bucket's hourly rate, and EUR. The user should usually only enter start and end time.

### Fixed Cost

A fixed cost is an adjustable cost item inside a bucket.

Fields:

- date or period
- title/description
- quantity
- unit amount in EUR
- calculated total
- billable flag, default true
- invoice lock/reference once finalized

Fixed costs are transparent by default on invoices and should usually render as separate invoice lines.

### Business Profile

V1 has one global ehrax.dev business/payment profile.

Fields:

- business/legal display name
- address
- email and website
- optional tax number or VAT ID fields
- IBAN, BIC, and account holder
- default payment terms, initially 14 days
- invoice number format, initially `EHX-YYYY-001`
- default configurable invoice note/tax note

## UX Design

The app follows Apple Notes' navigation and density.

On Mac and wide iPad:

```text
Projects sidebar | Bucket list | Bucket detail
```

On iPhone:

```text
Projects -> Buckets -> Bucket detail
```

Projects and buckets use emoji plus title. Primary actions live in native toolbars. The app should avoid spreadsheet-like tables in V1.

### Bucket Detail

Bucket detail is a calm, note-like list with live calculations.

Example:

```text
MVP

Today
10:00 - 12:00
2.00 h · 80 EUR/h · 160 EUR

Yesterday
14:00 - 16:30
2.50 h · 80 EUR/h · 200 EUR

Summary
Billable: 4.50 h · 360 EUR
Non-billable: 1.00 h
Fixed costs: 0 EUR
```

Tapping or clicking `+` in a bucket opens a small add-entry sheet. The default time-entry path asks only for start and end time. Date, note, billable toggle, and any later advanced fields stay secondary.

### Dashboard

Home is an attention and revenue surface, not the primary time-entry surface.

It shows:

- paid this month
- paid this year
- outstanding
- overdue
- expected revenue from buckets marked `ready`
- a simple monthly revenue graph based on paid invoices
- buckets ready to invoice
- draft invoices waiting for finalization
- finalized invoices not marked sent
- sent invoices not paid
- overdue invoices
- recent activity

## Invoice Flow

Invoices are created from a project, selected buckets, and a date range or all uninvoiced billable items.

Draft invoices:

- allow editable invoice metadata, notes, selected buckets, and date ranges
- do not have a final invoice number
- can be regenerated from current bucket data
- use the selected invoice template/profile

Finalizing an invoice:

- assigns the next invoice number
- snapshots line items, totals, rates, recipient details, note text, payment terms, due date, and template/profile metadata
- renders and stores a PDF snapshot
- locks included time entries and fixed costs
- moves the invoice to `finalized`

Invoice states:

- `draft`
- `finalized`
- `sent`
- `paid`
- `cancelled`

`overdue` is derived when the due date has passed and the invoice is not paid or cancelled.

Hourly bucket work appears as clean summary lines on the main invoice. Fixed costs appear as transparent separate lines. Detailed appendices are out of V1 scope and can be added later.

## Templates

V1 uses bundled HTML templates rendered to PDF through `WKWebView`.

Template rules:

- A4 layout
- plain HTML and CSS
- minimal typography
- simple line-item table
- payment details block
- configurable note block
- no editable template designer
- no complex branding in V1

The first supported invoice profile targets the current Swiss client invoiced in EUR. German Kleinunternehmer wording remains configurable and can be used by a later German template/profile.

## Sync and Persistence

Use SwiftData for local persistence and private CloudKit/iCloud sync if the project configuration supports it cleanly.

Rules:

- private single-user sync only
- local-first behavior
- no accounts or collaboration
- finalized invoice snapshots and locked entries should not silently mutate after sync

## AI Readiness

AI-generated descriptions are not part of the required V1 flow, but the model should not block them later.

Potential later support:

- optional notes on time entries
- generated summary fields
- source references such as repo path, branch, commit, PR, or ticket
- export/import of invoice draft context as JSON or Markdown
- future App Intents or macOS actions for automation

## Testing and Verification

V1 should include focused tests for:

- duration calculation
- billable and non-billable totals
- fixed cost totals
- bucket rate changes affecting unlocked entries
- finalized invoices preserving snapshotted rates/totals
- invoice number generation
- overdue state derivation

Manual verification should cover:

- Mac Notes-like navigation
- iPhone stacked navigation
- adding/editing time entries
- changing bucket rates before finalization
- generating and opening a simple A4 PDF
- CloudKit sync behavior, if enabled during implementation
