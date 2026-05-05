# PRD: Expenses Finance Cockpit

## Problem Statement

Pika currently helps freelancers understand incoming money through clients, projects, buckets, invoices, and dashboard revenue. It does not yet help them understand outgoing business costs, so a freelancer still has to dig through email, downloads, subscriptions, receipts, card statements, and ad hoc folders to answer the more important question: what did the business actually earn after costs?

Freelancers also need tax-relevant expense evidence to stay organized throughout the year. Without a calm place to record paid receipts, unpaid bills, subscriptions, equipment purchases, VAT details, and original evidence files, tax export becomes a manual scramble instead of a clean yearly handoff.

## Solution

Add an **Expenses** area to Pika as a first-class workspace surface near **Invoices**. An **Expense** is an amount-bearing business cost with a lifecycle of **Draft Expense**, **Due Expense**, **Paid Expense**, and **Archived Expense**. Expenses may attach zero, one, or many **Expense Evidence** files, such as invoice PDFs, receipt photos, payment screenshots, or other proof documents.

Expense intake starts from an add/import action in the Expenses toolbar. Uploading evidence starts or updates one intended Draft Expense, copies the evidence into Pika-managed storage, and may trigger AI extraction in the background. AI extraction produces draft suggestions, not authoritative finance data. The user confirms title, amount, currency, category, status, and relevant finance dates during **Expense Review** before the expense can count toward profit or tax exports. The detailed review interaction is intentionally design-pending and may become an AI chat-led sheet or overlay, but the confirmed structured Expense fields remain the source of truth.

Once reviewed, Expenses are managed through a calm list/detail pattern inspired by the existing Invoices view. The list uses chip-style states and filters. The detail view is evidence-first after review, with an explicit edit-details mode when the user needs to correct extracted data.

The Dashboard remains visually calm. The existing revenue chart title can become a metric dropdown that supports **Revenue** and **Actual Profit**. **Actual Profit** means paid invoice revenue minus paid expenses for the selected period. Dashboard **Needs Attention** can include actionable expense items such as due expenses, overdue expenses, drafts that need review, or missing evidence.

Tax exports are a separate concept from workspace archives. A **Workspace Archive** remains the full backup/restore package and must include expenses plus copied evidence. A **Tax Export** is a focused yearly handoff package of tax-relevant Paid Expenses, summaries, and evidence, organized category-first and flagging missing or unavailable evidence.

## User Stories

1. As a freelancer, I want an Expenses sidebar item near Invoices, so that outgoing business costs have a clear home.
2. As a freelancer, I want to upload a PDF invoice for a business purchase, so that Pika can create a Draft Expense from it.
3. As a freelancer, I want to upload a photo of a receipt, so that offline purchases can be recorded like online bills.
4. As a freelancer, I want one expense intake flow to accept multiple evidence files, so that a receipt and payment screenshot can belong to the same Expense.
5. As a freelancer, I want Pika to treat uploaded evidence as belonging to one intended Expense, so that unrelated mixed batch imports are not encouraged.
6. As a freelancer, I want Pika to flag unrelated uploaded files during review, so that accidental mixed uploads can be corrected.
7. As a freelancer, I want uploaded evidence copied into Pika-managed storage, so that deleting the original Downloads file does not break my records.
8. As a freelancer, I want evidence files to sync with my workspace through Apple cloud storage, so that my receipts and invoices are available on my other devices.
9. As a freelancer, I want Pika to show a syncing/loading state when metadata arrives before evidence files, so that synced attachments are not mistaken for missing evidence.
10. As a freelancer, I want to create a manual Expense without evidence, so that costs can be recorded even when no receipt is available yet.
11. As a freelancer, I want manual Expenses without evidence to be visibly flagged, so that I can fill gaps before tax handoff.
12. As a freelancer, I want AI to extract title, vendor name, amount, dates, VAT, currency, and category suggestions from evidence, so that review is faster.
13. As a freelancer, I want AI extraction to produce suggestions only, so that I remain in control of finance records.
14. As a freelancer, I want expense intake to create a persistent Draft Expense immediately, so that closing the sheet does not lose uploaded evidence or review progress.
15. As a freelancer, I want AI extraction to continue in the background, so that I can leave the intake flow and return later.
16. As a freelancer, I want Draft Expense rows to show a spinner or state when AI is working, so that I know extraction is still in progress.
17. As a freelancer, I want extraction failures to leave the Draft Expense and evidence intact, so that I can retry or enter details manually.
18. As a freelancer, I want a Draft Expense to count nowhere until reviewed, so that unconfirmed AI guesses do not affect profit or tax totals.
19. As a freelancer, I want to review and confirm title, amount, currency, category, status, and finance date, so that an Expense becomes reliable.
20. As a freelancer, I want a Paid Expense to require a Payment Date, so that paid-profit charts use the date money actually left.
21. As a freelancer, I want Due Expenses to represent unpaid obligations, so that I can follow up without reducing Actual Profit early.
22. As a freelancer, I want Paid Expenses to reduce Actual Profit by Payment Date, so that profit reflects real paid activity.
23. As a freelancer, I want payment proof to be optional, so that I can mark ordinary card charges as paid without unnecessary bureaucracy.
24. As a freelancer, I want each Expense to have a short title, so that lists show meaningful labels like "MacBook Pro" instead of only vendor names.
25. As a freelancer, I want optional notes on an Expense, so that I can record context that is not part of extracted evidence.
26. As a freelancer, I want vendor name as a simple field, so that I can search/filter without managing vendor profiles.
27. As a freelancer, I want Expenses to use workspace-wide Expense Categories, so that reporting and exports stay consistent.
28. As a freelancer, I want default Expense Categories, so that the app is useful on day one.
29. As a freelancer, I want to add, rename, and remove Expense Categories in Settings, so that categories match my business.
30. As a freelancer, I want renaming an Expense Category to update all uses, so that category cleanup is consistent.
31. As a freelancer, I want deleting a used category to require a replacement, so that expenses are not left with orphaned category labels.
32. As a freelancer, I want AI to suggest new categories during review, so that unusual expenses can still be categorized naturally.
33. As a freelancer, I want to approve new AI-suggested categories inline, so that I do not have to leave review for Settings.
34. As a freelancer, I want Pika to store original amount and currency, so that evidence remains faithful to the purchase.
35. As a freelancer, I want cross-currency Expenses to require a reviewed Reporting Amount in workspace currency, so that profit and exports use a consistent currency.
36. As a freelancer, I do not want Pika to fetch exchange rates automatically in v1, so that it does not silently choose the wrong conversion.
37. As a freelancer, I want VAT details extracted and stored when available, so that Pika is ready for non-Kleinunternehmer workflows.
38. As a freelancer, I want missing VAT details not to block review, so that no-VAT and unusual receipts can still be recorded.
39. As a freelancer, I want Actual Profit to use gross Reporting Amount in v1, so that the dashboard matches cash-out reality.
40. As a freelancer, I want an Expense to optionally link to one Project, so that project-specific costs can be understood later.
41. As a freelancer, I want Client to be implied from the linked Project, so that I do not have to duplicate relationships.
42. As a freelancer, I want most Expenses to stay workspace-wide, so that business-wide costs like software, equipment, domains, and office supplies are easy to record.
43. As a freelancer, I want v1 to avoid multi-project splits, so that expense capture stays simple.
44. As a freelancer, I want duplicate detection to be advisory during review, so that Pika can warn me without auto-merging or deleting records.
45. As a freelancer, I want duplicate warnings to offer attach, create separately, or ignore decisions, so that related evidence can be handled safely.
46. As a freelancer, I want evidence attachments to have optional Evidence Kind, so that invoices, receipts, payment proof, and other files are easier to review and export.
47. As a freelancer, I want evidence kind not to block review, so that uncertain files do not slow me down.
48. As a freelancer, I want extracted evidence text stored for search and duplicate detection, so that future search can find useful records.
49. As a freelancer, I want no separate document library in v1, so that Expenses remain the unit of organization.
50. As a freelancer, I want normal search to exclude Archived Expenses by default, so that archive behaves like my delete-like cleanup area.
51. As a freelancer, I want archived search when viewing archived expenses, so that I can find old or removed records intentionally.
52. As a freelancer, I want archiving to be the normal delete-like action for reviewed Expenses, so that records leave active views without immediate destruction.
53. As a freelancer, I want hard delete only from archived expenses, so that incorrect records can be removed deliberately.
54. As a freelancer, I want archived expenses excluded from normal Actual Profit charts and Tax Exports by default, so that invalid or removed records do not affect reporting.
55. As a freelancer, I want archiving to keep copied evidence, so that archived records remain inspectable.
56. As a freelancer, I want hard delete to remove Pika's copied evidence when no longer attached elsewhere, so that erroneous files do not linger in Pika storage.
57. As a freelancer, I want meaningful Expense lifecycle events in Activity, so that I can see history without noisy extraction details.
58. As a freelancer, I want draft extraction edits and minor AI suggestion changes omitted from Activity, so that history stays readable.
59. As a freelancer, I want the Expenses view to follow the Invoices list/detail pattern, so that the app feels familiar and calm.
60. As a freelancer, I want filters for states such as All, Draft, Due, Paid, and Archived, so that I can focus on the right expense set.
61. As a freelancer, I want selected-expense uploads to attach evidence to that expense, so that late payment screenshots or extra receipts are easy to add.
62. As a freelancer, I want uploads with no selected Expense to start a new Draft Expense, so that the add/import action is predictable.
63. As a freelancer, I want reviewed expenses to show an evidence-first detail view, so that the original bill or receipt remains central.
64. As a freelancer, I want edit details to be explicit, so that reviewed expense fields do not clutter the normal document view.
65. As a freelancer, I want intake/review design to be validated visually before final implementation, so that the chat-led sheet or overlay feels right.
66. As a freelancer, I want the Dashboard chart metric to switch between Revenue and Actual Profit, so that I can see both income and real earnings without a crowded dashboard.
67. As a freelancer, I want Dashboard Needs Attention to include due expenses, overdue expenses, and drafts, so that the dashboard tells me what needs action.
68. As a freelancer, I want due expenses shown as obligations instead of subtracting from Actual Profit, so that actual paid profit stays honest.
69. As a freelancer, I want Tax Export to include Paid Expenses by Payment Date for a selected year, so that yearly handoff matches paid business costs.
70. As a freelancer, I want Tax Export to exclude Draft, Due, and Archived Expenses by default, so that unreviewed, unpaid, or removed records do not pollute the package.
71. As a freelancer, I want Tax Export to include paid expenses that are missing evidence but flag them, so that I know what to fix before handoff.
72. As a freelancer, I want Tax Export to include VAT fields when known, so that tax preparation has richer data.
73. As a freelancer, I want Tax Export evidence organized category-first, so that the package is easier for an accountant or tax office to inspect.
74. As a freelancer, I want a summary file in Tax Export, so that amounts, categories, dates, VAT, and missing evidence can be reviewed quickly.
75. As a freelancer, I want Workspace Archive to include Expenses and Expense Evidence, so that backup/restore is complete.
76. As a freelancer, I want the existing Workspace Archive format extended instead of a separate expense archive, so that restore stays one coherent workflow.
77. As a freelancer, I want subscriptions to be ordinary Expenses in v1, so that recurring logic does not overcomplicate the first version.
78. As a freelancer, I want structured expense line items out of scope in v1, so that the system stays focused on expense-level records and evidence.
79. As a freelancer, I want AI analysis to happen only for files I intentionally import, so that Pika does not scan unrelated folders or documents.
80. As a freelancer, I want importing files into expense intake to be the confirmation for AI analysis, so that the privacy boundary is clear.

## Implementation Decisions

- Add an Expenses feature area with its own sidebar destination near Invoices.
- Extend the Workspace Module so WorkspaceStore exposes app-facing Expense commands while preserving the existing MV-first architecture direction.
- Add a deep Expense workflow/policy module that owns Expense lifecycle decisions: draft review, due/paid transitions, archive/hard-delete behavior, required fields, reporting eligibility, and duplicate/advisory outcomes.
- Add Expense projections for list rows, summaries, dashboard attention items, Actual Profit chart data, and tax export readiness.
- Extend WorkspaceSnapshot with expenses, expense categories, and evidence-facing read models while keeping SwiftData records as the durable persistence shape.
- Add SwiftData-compatible normalized records for Expenses, Expense Categories, Expense Evidence metadata, extraction state, extracted text, VAT details, reporting amount, and optional Project link.
- Store vendor name as a plain Expense field, not a managed Vendor object.
- Store original amount/currency and reviewed Reporting Amount in workspace currency; do not fetch exchange rates automatically in v1.
- Store VAT details from day one when available, including net amount, VAT amount, and VAT rate, while keeping gross Reporting Amount as the v1 profit amount.
- Model Expense Evidence as attachments copied into Pika-managed storage, respecting ADR 0001.
- Sync Expense Evidence with the workspace and tolerate eventual attachment availability, respecting ADR 0002.
- Represent Evidence Availability separately from "missing evidence" so the UI can distinguish syncing/unavailable files from expenses with no evidence attached.
- Add Evidence Kind as optional attachment metadata: invoice, receipt, payment proof, or other.
- Store extracted evidence text for expense search and duplicate detection, without creating a standalone document library.
- Add persistent Draft Expense creation at the start of intake, allowing the user to resume if the sheet or overlay closes.
- Keep Analyzing as an extraction state within Draft Expense rather than a separate Expense lifecycle status.
- Keep AI extraction advisory: it can update draft suggestions and provide review/chat assistance, but confirmed structured fields are authoritative.
- Make payment proof optional; Paid Expense requires Payment Date, not separate payment evidence.
- Add workspace-wide Expense Categories with defaults, Settings management, inline AI-suggested category approval, global rename, and replacement-on-delete for used categories.
- Keep Expense links optional and single-project only in v1; Client is derived from Project.
- Keep subscriptions as ordinary Expenses in v1.
- Keep structured expense line items out of scope in v1.
- Add duplicate detection as advisory review output; never auto-delete or auto-merge.
- Add Activity events for notable Expense lifecycle changes while excluding noisy extraction and field-edit churn.
- Add an Expenses list/detail view following the existing Invoices pattern.
- Keep reviewed Expense detail evidence-first, with explicit edit-details mode.
- Mark the exact intake/review interaction design as pending visual design or PRD refinement; current direction allows an AI chat-led sheet, overlay, or second-page flow.
- Extend Dashboard projections to support Actual Profit and a chart metric dropdown while keeping the dashboard visually calm.
- Extend Dashboard Needs Attention with actionable expense items.
- Add Tax Export as a focused yearly export separate from Workspace Archive.
- Extend the existing Workspace Archive format for Expenses and copied Evidence instead of creating a separate expense archive.

## Testing Decisions

- Tests should verify external behavior and domain outcomes rather than SwiftUI implementation details or internal helper calls.
- Expense lifecycle tests should cover Draft, Due, Paid, Archived, hard-delete eligibility, required review fields, payment-date requirements, archive exclusion, and manual no-evidence expenses.
- Reporting tests should cover Actual Profit as paid invoice revenue minus paid expenses, Payment Date placement, Due Expense exclusion, Draft Expense exclusion, Archived Expense exclusion, and cross-currency Reporting Amount requirements.
- Tax Export tests should cover selected-year eligibility by Payment Date, category-first organization metadata, missing evidence flags, unavailable evidence flags, VAT fields when available, and exclusion of Draft/Due/Archived expenses by default.
- Workspace Archive tests should extend existing archive export/import coverage to include expenses, categories, evidence metadata, and attachment references.
- Evidence storage tests should verify import copies files into Pika-managed storage and hard delete removes Pika's copy only when no longer referenced.
- Evidence availability tests should cover locally available, syncing, unavailable, and missing states.
- Category tests should cover defaults, inline suggested category approval, rename propagation, and replacement-required deletion.
- Duplicate detection tests should focus on advisory outputs and user choices, not on a brittle exact matching algorithm.
- Projection tests should mirror the existing WorkspaceProjectionTests style for dashboard and list summaries.
- Store mutation tests should mirror the existing WorkspaceStoreMutationTests style for app-facing commands and persistence reload behavior.
- Archive action tests should mirror existing WorkspaceArchiveActionsTests and WorkspaceArchiveImportValidationTests.
- UI tests should focus on high-value launch/navigation and visible-state checks for the Expenses sidebar, list filters, add/import entry point, draft resumption, and evidence-first detail once the visual design is settled.

## Out of Scope

- Generic tax documents that are not amount-bearing business Expenses.
- A separate managed Vendor domain object, vendor profiles, vendor merge flows, or vendor detail screens.
- Recurring Expense rules, subscription templates, or generated future expenses.
- Multi-project or multi-client allocation/splitting of one Expense.
- Structured expense line items.
- Automatic exchange-rate fetching or automated FX conversion.
- Full VAT accounting, VAT return preparation, tax advice, or organization-specific accounting workflows beyond storing VAT fields.
- Automatic background scanning of Downloads, email, folders, or unrelated files.
- A standalone document/evidence library or global document search surface.
- Silent AI authority over finance records; user review remains required before an Expense counts.
- Final visual design of the intake/review sheet, overlay, second-page flow, or AI chat interface.
- Re-invoicing Expenses to clients or replacing invoice FixedCostEntry behavior with supplier-bill pass-through.

## Further Notes

- The domain glossary in CONTEXT.md is the source of truth for Expense language.
- ADR 0001 records the decision to copy imported Expense Evidence into Pika-managed storage.
- ADR 0002 records the expectation that Expense Evidence syncs with the workspace and that UI handles evidence-file availability as eventually consistent.
- The feature should keep Pika small and native: calm list/detail surfaces, clear chip states, focused projections, and testable workflow modules.
- The current Invoices view is the strongest interaction reference for the reviewed Expenses area.
- The exact AI provider or harness is intentionally undecided. The product decision is that AI supports extraction and review; implementation can choose the provider later based on privacy, cost, latency, and local architecture constraints.
