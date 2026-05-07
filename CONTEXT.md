# Billbi Context

## Domain Language

- **Workspace**: the app-facing model of a freelancer's invoicing world. It includes the business profile, clients, projects, buckets, invoices, and activity visible to the app.
- **Client**: a billable customer with contact, billing address, payment terms, and archive state.
- **Project**: a body of work for a client. A project contains buckets and finalized invoices.
- **Bucket**: a project work package that collects time entries and fixed costs before it is ready to invoice.
- **Invoice**: a finalized billing document created from an invoiceable bucket. Its business, client, project, bucket, line-item, and status details are snapshotted at finalization time.
- **Expense**: an amount-bearing business cost the freelancer records for profit tracking, payment follow-up, and tax-deductible evidence.
- **Expense Title**: the short human label used to identify an expense in lists and summaries.
- **Expense Notes**: optional user-written context for an expense.
- **Expense Evidence**: an original invoice, receipt, or similar proof document attached to an expense, regardless of whether it is a PDF or image.
- **Evidence Kind**: an optional label for expense evidence such as invoice, receipt, payment proof, or other.
- **Evidence Availability**: whether an attached evidence file is locally available, still syncing, unavailable, or genuinely missing.
- **Expense Category**: a user-approved label that groups expenses for understanding costs and preparing exports.
- **Draft Expense**: an expense whose extracted or entered details still need review before it counts toward profit or tax reporting.
- **Due Expense**: a reviewed expense whose payment is still open.
- **Paid Expense**: a reviewed expense whose payment is complete.
- **Archived Expense**: an expense kept for records but hidden from normal active expense views.
- **Document Date**: the date printed on an expense's evidence or entered as the business date of the expense.
- **Due Date**: the date by which a due expense should be paid.
- **Payment Date**: the date money actually left the freelancer's account or card for a paid expense.
- **Reporting Amount**: the reviewed amount of an expense in the workspace currency used for profit charts and exports.
- **Expense VAT**: reviewed tax details extracted from expense evidence, such as net amount, VAT amount, and VAT rate.
- **Expense Review**: the user confirmation step where extracted expense suggestions become finance records.
- **Actual Profit**: paid invoice revenue minus paid expenses for a selected period.
- **Workspace Archive**: a full backup or transfer package for restoring a Billbi workspace.
- **Tax Export**: a focused yearly handoff package of tax-relevant paid expenses, summaries, and evidence.
- **Activity**: a local audit-style event shown in the app for notable workspace changes.

## Product Design Language

- **Brand Color**: Billbi's canonical purple/lavender used for branded interactive UI such as buttons, focused inputs, selected chips, toolbar actions, and app tint.
  _Avoid_: Accent color, primary color
- The Swift design token for **Brand Color** should be `BillbiColor.brand`, with derived tokens `brandMuted` and `brandBorder` for subtle fills and outlines.
- Single-series branded charts should use `BillbiColor.brand`; chart fills may use stronger local opacity from `brand` instead of introducing a separate purple shade.
- The darker brand-family shade used for selected rows in the primary sidebar should be `BillbiColor.primarySidebarSelection`; do not use it for general buttons, chips, charts, or focused inputs.
- Focused input outlines should use `BillbiColor.brandBorder` and the shared width token `inputFocusBorderWidth`; move non-color dimensions out of `BillbiColor` if a broader stroke/input token namespace emerges.
- The asset-catalog `AccentColor` should match **Brand Color** in light and dark appearances so system accent surfaces do not introduce a third purple.
- Color-token refactors should include a dark-mode visual audit of representative buttons, focused inputs, selected chips, charts, and primary sidebar selection using local macOS screenshots where practical.

## Flagged Ambiguities

- "Pika" was an early product name that may appear in design prototypes; the shipped product and app-facing copy should say **Billbi**.
- Onboarding is a skippable first-run setup helper for collecting business, client, project, and bucket information. It should not block entering the app because freelancers may not have every business detail ready yet. Once completed or skipped, onboarding is marked done permanently for that workspace and should not automatically run again.
- Skipping onboarding should not block workspace exploration, but invoice finalization should block until the specific sender and invoice-required business details are complete.
- For Swiss-style invoices, Billbi should distinguish invoice-required sender details from conditionally required VAT details. Supplier name and address, recipient name and address, service date or period, service description, price, and invoice tax treatment are invoice-critical. A Swiss VAT number is required only when the business is VAT-registered; exempt freelancers should not be forced to enter one before invoicing.
- For German-style invoices, Billbi should distinguish ordinary invoices, small-amount invoices, and Kleinunternehmer invoices. Ordinary German invoices require the supplier's tax number or VAT ID, while Kleinunternehmer invoices must clearly state the small-business tax exemption and must not show VAT as if it were charged.
- Billbi should avoid turning first-run onboarding into a country-specific tax setup. Near-term onboarding should collect minimal global invoicing defaults, while future country or project-specific tax configuration can tighten invoice validation for each jurisdiction.
- Tax identifiers entered during onboarding are optional setup metadata in the near term. A missing tax identifier should not block onboarding completion; stricter tax validation belongs to later country or project-specific invoice configuration.
- The near-term onboarding "ground setup" should aim to collect business name, invoice email, business address, currency, default hourly rate, and default payment terms. Legal or person name, tax ID or VAT number, phone, website, and payment details are useful but optional.
- Optional onboarding steps for first client, project, and bucket should create real workspace records when the user completes them. Skipping optional steps should not create placeholder clients, projects, or buckets.
- Onboarding should create a first bucket when the user chooses to create a first project, so the project is immediately usable for tracking and invoicing. Skipping project setup should not create a placeholder project or bucket.
- A Project requires a Client. In onboarding, project setup depends on first creating a client, and project creation should create the initial bucket for that project.
- Onboarding should present the setup chain as separate screens: business setup, first client, and first project with its initial bucket. The separation teaches the Client -> Project -> Bucket model without combining the forms into one large step.
- Onboarding should allow skipping from any screen. If the user skips after completing earlier steps, Billbi should keep the real records or profile changes already saved and mark onboarding done.
- Each completed onboarding step should save immediately to real workspace state. Onboarding should not depend on a final all-or-nothing commit.
- The onboarding welcome screen is visual step 1. It introduces the setup flow but does not itself create workspace data.
- Choosing "Skip setup" from any onboarding screen should mark onboarding done and enter the main app immediately. The final ready screen is shown only when the user reaches the end of the setup flow.
- Onboarding should avoid separate per-step "skip for now" controls. The flow uses Back, a primary Continue action, and the global Skip setup action. Optional later setup can be skipped only by leaving onboarding through Skip setup.
- "cost" exists in invoiceable bucket language as a fixed cost that can be billed to a client; use **Expense** for outgoing amount-bearing business costs tracked for profit and tax clarity.
- "tax document" was considered for generic tax paperwork, but Billbi's near-term scope is tax-relevant **Expenses** such as subscriptions, domains, equipment, and other business running costs.
- "receipt" and "invoice PDF" both refer to **Expense Evidence** when they prove an outgoing business cost; do not model them as separate top-level records.
- "batch import" was considered for mixed uploads, but Billbi's expense intake flow is centered on one intended **Expense** at a time; multiple uploaded files should be treated as evidence for that intended expense and flagged for review if they appear unrelated.
- "bill" refers to a **Due Expense** when it is an unpaid outgoing business cost; do not model it as a separate top-level record.
- The product surface should call the area **Expenses**, not Bills or Costs.
- **Expenses** should have their own sidebar destination near **Invoices**.
- "fixed cost" currently means an invoiceable project line item; future work may allow selected **Expenses** to be re-invoiced to clients, but v1 should keep outgoing **Expenses** distinct from invoice line items.
- "vendor" is useful as a plain vendor-name field on an **Expense**, but should not be a separate managed domain object in v1.
- "category" should be controlled by user-approved **Expense Categories**; AI may suggest a new category during review, but it should not silently expand the category list.
- "subscription" is not a separate recurring domain object in v1; repeated subscription bills are recorded as ordinary **Expenses**.
- Duplicate detection for **Expenses** is advisory in review; Billbi may flag likely duplicates or related evidence, but the user decides whether to attach, create separately, or ignore.
- Billbi v1 should not have a separate document or evidence library; evidence is accessed through its **Expense**.
- Normal expense search excludes **Archived Expenses** unless the user is searching the archived view.
- Billbi v1 should not model structured expense line items; the reviewed expense is the finance record and the original evidence remains available for detail.
- AI extraction produces draft suggestions for **Expense Review**, not authoritative finance data.
- Extracted evidence text may be stored for expense search and duplicate detection, without creating a standalone document-search surface in v1.
- Importing files into an expense intake flow is the user's confirmation that those files may be analyzed for expense extraction.
- Billbi should not scan or analyze files that the user has not intentionally imported into an expense intake flow.

## Architecture Language

- **Workspace Module**: the app-facing module that SwiftUI uses to read workspace state and issue workspace commands.
- **WorkspaceStore**: the observable coordinator for the Workspace Module. It should expose stable app-facing commands while delegating persistence, projections, and invoicing decisions to deeper modules.
- **WorkspacePersistence**: the module that owns SwiftData, CloudKit-compatible normalized records, seed import, save, load, and reload behavior. `ModelContext` should stay hidden behind this module instead of flowing through views or domain workflow.
- **WorkspaceProjections**: the module that builds dashboard, project, bucket, and invoice read models from workspace data.
- **WorkspaceInvoicingWorkflow**: the production-used module that owns invoice readiness, finalization, and invoice status workflow decisions.
- **WorkspaceSnapshot**: the app-facing read model/cache that SwiftUI can render efficiently. It should stay separate from SwiftData normalized records, which remain the durable persistence shape.

## Current Architecture Direction

- Keep `WorkspaceStore` as Billbi's app-facing Workspace Module for now.
- Deepen its implementation rather than replacing it with a Redux-style reducer or a Flutter BLoC-style event hub.
- Treat SwiftData plus private CloudKit as load-bearing persistence.
- Inject `ModelContext` at app composition time, then keep it inside `WorkspacePersistence`.
- Keep SwiftUI views focused on local presentation state, projections, and calls to `WorkspaceStore` commands.
- Keep Billbi MV-first for SwiftUI. Use lightweight DDD-informed layering only to name where domain decisions live:
  - SwiftUI views are presentation.
  - `WorkspaceStore` is the application coordinator.
  - `WorkspaceInvoicingWorkflow`, `WorkspaceMutationPolicy`, and `InvoiceWorkflowPolicy` own domain decisions.
  - `WorkspaceSnapshot` and `WorkspaceProjections` are read models for app rendering.
  - `WorkspacePersistence`, SwiftData records, and CloudKit sync are infrastructure.
- Domain workflow should not depend on SwiftData, CloudKit, or `ModelContext`.

## Workspace Store Deepening Decisions

- Break up the current Workspace Store Module as one coherent architecture effort, then split the work into implementation tickets.
- Preserve the public `WorkspaceStore` interface where practical so SwiftUI feature views can continue to call app-facing commands.
- `WorkspaceInvoicingWorkflow` should work with snapshot/value inputs first, not SwiftData records.
- Invoice workflow should return an `InvoiceFinalizationResult`-style business outcome rather than a full mutated `WorkspaceSnapshot`.
- Activity is application/store-owned. Domain workflow should expose enough facts for `WorkspaceStore` to create activity, but should not create activity records itself.
- `WorkspacePersistence` applies durable invoice finalization effects, including inserting invoice records, marking buckets finalized, incrementing `nextInvoiceNumber`, saving, and reloading.
- Invoice number uniqueness should be checked in both workflow and persistence:
  - workflow checks the current `WorkspaceSnapshot` for fast domain feedback,
  - persistence checks durable SwiftData records before write to guard against stale snapshots or CloudKit sync changes.
- On stale persistence or CloudKit-sensitive conflicts, throw and reload. Do not auto-retry finalization for now.
- Keep existing `WorkspaceStoreError` behavior where practical, but introduce a distinct persistence conflict error/case for stale or CloudKit-sensitive writes.

## Relationships

- An **Expense** may have zero, one, or many **Expense Evidence** attachments.
- **Evidence Kind** helps review and export attached files, but does not block expense review.
- **Expense Evidence** files are copied into Billbi-managed storage when imported.
- **Expense Evidence** should sync through the user's Apple cloud storage path; expense metadata may become visible before evidence files finish syncing.
- If expense metadata references evidence that is not locally available yet, Billbi should show a syncing or unavailable evidence state rather than treating the expense as missing evidence.
- An **Expense** may be reviewed without **Expense Evidence**, but should remain visibly flagged as missing evidence.
- Archiving is the normal delete-like action for **Expenses**; hard deletion is only available for archived expenses when a record was created incorrectly.
- **Archived Expenses** are excluded from normal actual-profit charts and tax exports by default.
- Archiving an **Expense** keeps its copied **Expense Evidence** in Billbi storage; hard deletion removes Billbi's copy when the evidence is no longer attached elsewhere.
- **Activity** includes notable **Expense** lifecycle events, but not every draft extraction, review-field edit, or AI suggestion change.
- One expense intake flow is intended to create or update exactly one **Expense**.
- Uploading evidence while an active **Expense** is selected should attach it to that expense; uploading with no selected expense should start a new **Draft Expense**.
- An **Expense** belongs to the **Workspace** and may optionally link to one **Project**.
- **Expense Categories** belong to the **Workspace** and are reused by expenses.
- **Expense Title** is the primary list label; vendor name, category, and finance dates are supporting details.
- Renaming an **Expense Category** updates that label everywhere it is used.
- Deleting a used **Expense Category** requires moving its expenses to a replacement category.
- Billbi should ship with default **Expense Categories**, and users can add, rename, or remove them in Settings.
- AI-suggested new **Expense Categories** can be approved inline during **Expense Review**.
- When an **Expense** links to a **Project**, its **Client** is implied by that project.
- Billbi v1 does not split one **Expense** across multiple projects or clients.
- A **Draft Expense** does not count toward profit or tax/export totals.
- A **Due Expense** represents an outstanding obligation but does not reduce actual paid profit.
- A **Paid Expense** reduces actual paid profit and is eligible for tax/export totals.
- A **Paid Expense** is placed in actual-profit charts by **Payment Date**.
- **Actual Profit** includes paid invoices and paid expenses only; due expenses are shown as outstanding obligations instead of reducing actual profit.
- The Dashboard should stay visually calm: the existing revenue chart title can become a metric/dashboard dropdown for **Actual Profit** and revenue rather than adding a separate dense expense dashboard.
- Dashboard **Needs Attention** can include actionable expense items such as due expenses that need payment soon.
- The **Expenses** area should follow the calm list/detail pattern of **Invoices**, with expense filtering and evidence/detail review in the detail pane.
- Initial **Expense Review** design should validate a side-by-side layout with evidence preview and editable extracted fields.
- After **Expense Review** is complete, the detail view should become evidence-first like the finalized invoice preview; the review data panel should not stay permanently visible.
- Reviewed expense details should be changed through an explicit edit-details mode rather than always showing editable fields.
- The **Expenses** toolbar should include an add/import action that starts expense intake.
- Expense intake should start in a sheet that supports uploading evidence or creating a manual expense.
- Starting expense intake creates a persistent **Draft Expense** so the review process can be resumed if the sheet closes.
- AI extraction for a **Draft Expense** may continue in the background; the expense list should show chip-style states such as analyzing, draft, due, paid, or archived.
- Analyzing is an extraction state within **Draft Expense**, not a separate expense lifecycle status; UI may show a spinner while AI work is active.
- Failed AI extraction keeps the **Draft Expense** and its evidence intact; the user can retry extraction or complete the expense manually.
- The expense intake sheet may be AI chat-led, where the user reviews and corrects extracted details conversationally before confirming the **Draft Expense**.
- Detailed expense intake and review interaction design is intentionally deferred until visual designs or a PRD exist; current language captures domain boundaries, not final screen structure.
- A **Draft Expense** becomes reviewed only after the user confirms its title, amount, currency, category, status, and relevant finance date.
- A **Paid Expense** requires a **Payment Date** before it can count toward actual profit.
- Payment proof is optional; a user may mark a reviewed **Expense** as paid by confirming its **Payment Date**.
- Cross-currency **Expenses** keep their original amount and currency, but require a reviewed **Reporting Amount** in the workspace currency before they count toward profit or exports.
- Billbi v1 should not fetch exchange rates automatically for **Expenses**.
- **Expense VAT** should be extracted and stored from day one when available, but missing VAT details do not block expense review in v1.
- Billbi v1 uses the gross **Reporting Amount** for actual-profit calculations.
- A **Workspace Archive** includes expenses and their copied **Expense Evidence** so the workspace can be restored completely.
- The existing **Workspace Archive** format should be extended for expenses instead of creating a separate expense archive.
- A **Tax Export** includes tax-relevant paid expenses and evidence for a selected year, not the full workspace.
- **Tax Export** eligibility is based on **Paid Expenses** in the selected year by **Payment Date**.
- A **Tax Export** should include paid expenses with missing evidence, flagged so the freelancer can fill the gaps before handoff.
- A **Tax Export** should include a summary file and organize evidence category-first for accountant or tax-office handoff.
