# PRD: Global Invoice Identity and Payment Methods

## Problem Statement

Billbi is becoming useful beyond its original German/SEPA-shaped assumptions, but the current settings model still treats tax identity and payment details as a small fixed set of fields. Freelancers across countries need to print different tax identifiers, registration numbers, customer tax IDs, payment instructions, and payment rails on invoices. Those details vary widely: Germany may use Steuernummer and USt-IdNr, Switzerland may use UID/VAT, the UK may use VAT registration number and company number, Australia may use ABN, the US may use EIN cautiously, and payment may happen through SEPA, SWIFT, Wise, PayPal, payment links, or other local instructions.

The app must support this global variety without becoming tax software or making freelancers feel like they are designing a database. Billbi should help users print the invoice details they know are correct, validate payment details enough that clients can pay, keep invoice creation calm, preserve historical invoices, and continue importing production data that uses the old flat business profile model.

## Solution

Add a simple global invoice identity layer built around **Tax/Legal Fields** and **Payment Methods**.

**Tax/Legal Fields** are editable label/value details that can be printed on invoices for tax identifiers, registration numbers, exemption references, client VAT IDs, or other legal invoice details. They are display data, not tax calculation rules. Billbi may suggest common fields from a small curated country preset catalog, but suggestions are optional, editable, and non-blocking. Tax/Legal Fields can belong to the Workspace sender profile or to a Client recipient profile. Invoice-specific structured Tax/Legal Fields are deferred; one-off legal or tax text stays in the ordinary invoice note.

**Payment Methods** are typed reusable ways the freelancer accepts payment, such as SEPA bank transfer, international bank transfer, PayPal, Wise, payment link, or other. Payment Methods own their printable fields and placement as a whole because payment instructions and QR code behavior need to stay together. A Workspace may store many Payment Methods with one default. A Client may prefer one Workspace Payment Method. Invoice creation resolves the selected Payment Method from invoice override, Client preference, and Workspace default, then snapshots that selected method onto the finalized Invoice.

The current bundled invoice templates should render semantic slots such as sender Tax/Legal Fields, recipient Tax/Legal Fields, footer Tax/Legal Fields, and footer Payment Method. Placement is a default rendering hint for bundled templates, not a hard limit on future custom HTML templates. Future template editing can use canonical field collections directly.

The feature must include a migration path from the current flat fields: legacy tax identifier and economic identifier become business Tax/Legal Fields, and legacy payment details become a default Payment Method. Workspace Archive support must remain backward-compatible with existing production archives and import paths.

## User Stories

1. As a freelancer, I want Billbi to support invoice identity details from many countries, so that I can use the app outside one fixed tax system.
2. As a freelancer, I want tax and legal invoice details to be editable label/value rows, so that I can enter the fields my business actually needs.
3. As a freelancer, I want Tax/Legal Fields to support labels such as Steuernummer, VAT ID, UID, ABN, GST/HST No., EIN, or company number, so that local invoice terminology can appear correctly.
4. As a freelancer, I want Tax/Legal Fields to be optional display data, so that Billbi helps without blocking me with tax-compliance assumptions.
5. As a freelancer, I want Billbi not to validate tax identifier formats in v1, so that unusual or country-specific formats are not rejected incorrectly.
6. As a freelancer, I want empty Tax/Legal Fields not to print, so that unfinished details do not create messy invoices.
7. As a freelancer, I want Billbi to trim and clean Tax/Legal Field values lightly, so that accidental whitespace does not appear on invoices.
8. As a freelancer, I want Tax/Legal Fields stored as invoice data rather than template-only text, so that multiple templates can reuse the same facts.
9. As a freelancer, I want changing a Tax/Legal Field in Settings to affect future invoices, so that I do not need to edit every template manually.
10. As a freelancer, I want finalized invoices to snapshot rendered Tax/Legal Fields, so that old invoices do not change when my profile changes later.
11. As a freelancer, I want my business Tax/Legal Fields in Settings, so that sender invoice identity is configured once.
12. As a freelancer, I want Client Tax/Legal Fields in Client detail, so that recipient VAT IDs or registration numbers can appear on invoices for specific clients.
13. As a freelancer, I want Client Tax/Legal Fields to appear in a normal Tax & Legal section, so that the feature is discoverable without feeling like hidden enterprise configuration.
14. As a freelancer, I want Client Tax/Legal Fields to default near recipient details, so that client VAT IDs naturally appear with the client address.
15. As a freelancer, I want business Tax/Legal Fields to default near sender details, so that my tax identity appears with my business information.
16. As a freelancer, I want to choose a placement for each Tax/Legal Field, so that some details can appear near sender details, recipient details, or the footer.
17. As a freelancer, I want to hide a Tax/Legal Field without deleting it, so that I can keep data for later without printing it now.
18. As a freelancer, I want placement to be simple, so that I choose from sender details, recipient details, footer, or hidden instead of designing layouts.
19. As a freelancer, I want placement to be a template hint, so that future custom templates can still arrange semantic data flexibly.
20. As a freelancer, I want one-off legal or tax text to stay in invoice notes for v1, so that invoice creation does not become a structured tax form.
21. As a freelancer, I want invoice-specific structured Tax/Legal Fields deferred, so that the create-invoice flow stays light.
22. As a freelancer, I want to select my business country/region from a country picker, so that Billbi can use stable country data without free-text ambiguity.
23. As a freelancer, I want Billbi to store country/region as an ISO alpha-2 country code, so that presets and archives stay stable across languages.
24. As a freelancer, I want localized country display names, so that the UI feels natural in my language later.
25. As a freelancer, I want country-based suggested Tax/Legal Fields, so that I can quickly add common invoice fields for my country.
26. As a freelancer, I want preset suggestions to be optional, so that Billbi does not pretend every suggestion applies to my business.
27. As a freelancer, I want preset suggestions to create normal editable fields, so that I can rename, hide, move, or delete them.
28. As a freelancer, I want preset suggestions to avoid “required” language, so that I understand they are helpers, not legal advice.
29. As a freelancer, I want unknown countries to still work with manual Tax/Legal Fields, so that global use is not blocked by the preset catalog.
30. As a freelancer, I want onboarding to ask for business country/region without forcing tax setup, so that first launch stays calm.
31. As a freelancer, I want onboarding to offer optional country suggestions after country selection, so that I can set up common invoice fields quickly if I want.
32. As a freelancer, I want to skip onboarding Tax/Legal Field suggestions, so that missing tax details do not block entering the app.
33. As a freelancer, I want Settings to show the full Tax & Legal editor later, so that I can complete invoice identity details when ready.
34. As a maintainer, I want Tax/Legal Field presets in a standalone JSON configuration file, so that agents and maintainers can audit and update suggestions easily.
35. As a maintainer, I want preset countries to include source metadata, so that future reviews can see where suggested labels came from.
36. As a maintainer, I want the first preset catalog to be small, so that Germany, Austria, Switzerland, United Kingdom, United States, Australia, Canada, Netherlands, France, Spain, and Italy can be reviewed carefully.
37. As a freelancer, I want many Payment Methods in my Workspace, so that I can accept payment through different rails.
38. As a freelancer, I want one Workspace default Payment Method, so that invoices have a sensible fallback.
39. As a freelancer, I want a Client to have a preferred Payment Method, so that different clients can pay by different methods.
40. As a freelancer, I want the Client preferred Payment Method editable in Billing details, so that client-specific payment behavior lives with other client billing setup.
41. As a freelancer, I want the Client preferred Payment Method shown in Invoice defaults, so that I can preview what future invoices will use.
42. As a freelancer, I want invoice creation to default to the Client preferred Payment Method when set, so that I do not need to choose it every time.
43. As a freelancer, I want invoice creation to fall back to the Workspace default Payment Method when the Client has no preference, so that every invoice has a payment path.
44. As a freelancer, I want invoice creation to allow a compact Payment Method override, so that one special invoice can use a different method without changing the Client profile.
45. As a freelancer, I do not want invoice creation to expose the full payment editor, so that finalizing an invoice stays focused.
46. As a freelancer, I want a finalized Invoice to render exactly one Payment Method in v1, so that clients get clear payment instructions.
47. As a freelancer, I want payment instructions to stay together, so that account holder, IBAN, BIC, payment link, and QR code are not scattered across the invoice.
48. As a freelancer, I want Payment Method placement to be footer or hidden in v1, so that payment details remain predictable.
49. As a freelancer, I want SEPA bank transfer as a typed Payment Method, so that Billbi can format IBAN and generate SEPA QR codes.
50. As a freelancer, I want international bank transfer as a typed Payment Method, so that SWIFT-style payment details can be printed cleanly.
51. As a freelancer, I want PayPal as a typed Payment Method, so that clients can pay using my PayPal email or link.
52. As a freelancer, I want Wise as a typed Payment Method, so that clients can use my Wise instructions.
53. As a freelancer, I want payment link as a typed Payment Method, so that online checkout links can appear on invoices.
54. As a freelancer, I want an Other Payment Method type, so that unusual or local payment instructions are still possible.
55. As a freelancer, I want SEPA QR codes only when the selected method has a valid IBAN and the invoice currency is EUR, so that QR codes are useful and not misleading.
56. As a freelancer, I want BIC/SWIFT to be optional for SEPA when possible, so that missing optional details do not over-block me.
57. As a freelancer, I want typed Payment Methods to validate known formats, so that typos in IBAN, BIC/SWIFT, email, or URL are caught early.
58. As a freelancer, I want finalization blocked when the selected Payment Method cannot produce valid printable instructions, so that clients are not sent invoices they cannot pay.
59. As a freelancer, I want optional-but-useful payment fields to warn rather than block, so that Billbi guides me without becoming heavy.
60. As a freelancer, I want finalized invoices to snapshot the selected Payment Method, so that old invoices keep the payment details used at finalization.
61. As a freelancer, I want changing my bank details to affect future invoices only, so that historic PDFs remain accurate.
62. As a freelancer, I want deleting a live Payment Method not to mutate finalized invoices, so that historical invoice records are safe.
63. As a freelancer, I want deleting a Client preferred Payment Method to clear that preference, so that future invoices fall back to the Workspace default.
64. As a freelancer, I want deleting the Workspace default Payment Method to require choosing another valid default before finalizing future invoices, so that invoice payment instructions remain complete.
65. As a freelancer with existing data, I want my old payment details migrated into a Payment Method, so that production workspaces keep working.
66. As a freelancer with existing SEPA details, I want legacy IBAN/BIC text to become a SEPA bank transfer method, so that QR code behavior continues.
67. As a freelancer with arbitrary legacy payment text, I want it migrated into an Other method, so that nothing is lost.
68. As a freelancer with existing tax identifiers, I want legacy tax identifier and economic identifier values migrated into business Tax/Legal Fields, so that invoice identity remains visible.
69. As a freelancer, I want Workspace Archives with old business profile fields to import successfully, so that backups remain usable.
70. As a freelancer, I want new Workspace Archives to include structured Tax/Legal Fields and Payment Methods, so that backup/restore preserves the new model.
71. As a freelancer, I want archive support to be additive and backward-compatible, so that existing production archives are not stranded.
72. As a freelancer, I want invoice snapshots in archives to preserve rendered Tax/Legal Fields and payment instructions, so that restored invoices match the original.
73. As a freelancer, I want the bundled classic invoice template to render dynamic sender Tax/Legal Fields where the old fixed tax identifiers appeared, so that the template improves without losing its look.
74. As a freelancer, I want the bundled template to omit empty tax/legal sections, so that invoices do not show blank labels or wasted space.
75. As a freelancer, I want the bundled payment footer to render the selected Payment Method fields and QR code when available, so that clients see clear instructions.
76. As a future template customizer, I want templates to receive canonical field collections as well as placement-filtered collections, so that future custom HTML can arrange data freely.
77. As a maintainer, I want template rendering to use semantic invoice data, so that templates do not need to know about old German-only field names.
78. As a maintainer, I want Tax/Legal Field and Payment Method rules in testable modules, so that validation, preset creation, migration, and rendering context behavior can be tested without UI fragility.
79. As a maintainer, I want payment validation to be isolated, so that IBAN/BIC/email/URL rules can evolve safely.
80. As a maintainer, I want country preset loading to be isolated, so that bad JSON, missing countries, duplicate keys, and source metadata can be tested directly.
81. As a maintainer, I want invoice finalization readiness to account for selected Payment Method validity, so that store and workflow behavior remain consistent.
82. As a maintainer, I want migration behavior covered by tests, so that production users do not lose tax or payment details.
83. As a maintainer, I want archive import/export tests for both legacy and structured formats, so that compatibility remains intentional.
84. As a freelancer, I want Billbi to remain simple invoice software, so that I can invoice globally without being dragged into tax-compliance setup.

## Implementation Decisions

- Model Tax/Legal Fields as label/value invoice display data with owner, placement, visibility, stable key, and ordering.
- Support sender Tax/Legal Fields on the Workspace/business profile and recipient Tax/Legal Fields on Clients.
- Defer invoice-specific structured Tax/Legal Fields; ordinary invoice note remains the v1 escape hatch for one-off legal or tax text.
- Keep Tax/Legal Fields non-blocking in v1. Billbi may trim values and avoid printing incomplete fields, but it should not validate tax identifier formats or block invoice finalization because a Tax/Legal Field is missing.
- Store business country/region as an ISO 3166-1 alpha-2 country code and render localized display names.
- Add a tiny curated Tax/Legal Field preset catalog as standalone JSON product configuration.
- The first preset catalog should cover Germany, Austria, Switzerland, United Kingdom, United States, Australia, Canada, Netherlands, France, Spain, and Italy.
- Presets should include stable keys, labels, owner, default placement, ordering, and source metadata. Presets should not encode legal requirements, tax calculation rules, blocking validation, or tax-status workflows.
- Onboarding may show optional country-based Tax/Legal Field suggestions after business country/region is selected. Skipping suggestions must not block onboarding.
- Settings should expose Tax & Legal as a normal area for sender fields.
- Client detail should expose Tax & Legal as a normal section for recipient fields, defaulting to recipient-details placement.
- Tax/Legal Field placement should be per field and limited to sender details, recipient details, footer, or hidden in the user-facing v1 UI.
- Placement is a bundled-template rendering hint, not a hard constraint on future custom templates.
- Model Payment Methods as typed reusable ways the freelancer accepts payment.
- V1 Payment Method types are SEPA bank transfer, international bank transfer, PayPal, Wise, payment link, and other.
- Payment Method placement belongs to the whole method, not individual payment fields.
- V1 Payment Method placement is footer or hidden.
- SEPA bank transfer is the only v1 method that generates a payment QR code. The QR code renders only for EUR invoices with an IBAN.
- A Workspace may store many Payment Methods and has one default Payment Method.
- A Client may choose one preferred Payment Method from the Workspace's methods.
- Invoice creation resolves Payment Method from explicit invoice selection, then Client preferred method, then Workspace default.
- Invoice creation may override the resolved Payment Method through a compact selector, but must not expose the full payment method editor.
- A v1 Invoice renders exactly one Payment Method.
- Invoice finalization blocks when the selected Payment Method cannot produce valid printable payment instructions.
- Typed Payment Methods may validate IBAN, BIC/SWIFT, email, and URL where those formats are known. Optional-but-useful fields should warn rather than block.
- Finalized Invoices snapshot the rendered Tax/Legal Fields and selected Payment Method, including printable fields and payment QR source data.
- Live Payment Methods are reusable defaults for future invoices only. Deleting live methods must not mutate finalized invoices.
- Deleting a Payment Method clears Client preferences that reference it. Deleting the Workspace default requires choosing another valid default before future invoices can be finalized.
- Migrate legacy business profile payment details into the Workspace default Payment Method. IBAN-containing text becomes a SEPA bank transfer method; otherwise it becomes an Other method with printable instructions.
- Migrate legacy tax identifier and economic identifier values into business Tax/Legal Fields.
- Extend Workspace Archive support additively, preserving legacy import paths for old business profile tax identifier, economic identifier, and payment details fields.
- New archives should preserve structured Tax/Legal Fields, Payment Methods, Client preferences, Workspace default Payment Method, and invoice snapshots.
- Update invoice rendering context to expose both placement-filtered collections for bundled templates and canonical collections for future custom templates.
- Update bundled invoice templates to render dynamic sender/client/footer Tax/Legal Fields and selected Payment Method instructions without empty section artifacts.
- Keep ADR 0005 as the architectural rationale for flexible Tax/Legal Fields and typed Payment Methods.

Major modules to build or modify:

- Workspace business profile model and commands for business country, sender Tax/Legal Fields, Payment Methods, and Workspace default Payment Method.
- Client model and commands for recipient Tax/Legal Fields and preferred Payment Method.
- Invoice finalization workflow for payment-method resolution, payment validation, and snapshotting.
- Payment Method domain module for typed schemas, printable instruction generation, validation, deletion/reference behavior, and SEPA QR source data.
- Tax/Legal Field domain module for field ownership, placement, ordering, preset application, cleanup, and rendering grouping.
- Tax/Legal preset catalog module for loading, decoding, auditing, and applying JSON presets.
- Invoice render context and template renderer for dynamic field collections and selected payment method rendering.
- Workspace persistence, archive export/import, and migration adapters for legacy and structured data.
- Settings, onboarding, client detail, and create-invoice UI surfaces for the new fields and compact selectors.

## Testing Decisions

- Tests should focus on external behavior and stable domain outcomes rather than SwiftUI view internals.
- Tax/Legal Field tests should cover owner, placement defaults, ordering, hidden behavior, empty-value omission, preset application, and non-blocking finalization.
- Preset catalog tests should cover JSON decoding, supported country lookup, missing country behavior, duplicate key handling, source metadata presence, and conversion from preset to editable fields.
- Country tests should verify ISO alpha-2 storage and localized display-name rendering boundaries where practical.
- Payment Method tests should cover each v1 type's required printable data, validation behavior, warnings for optional-but-useful fields, and printable instruction generation.
- SEPA tests should cover IBAN normalization/validation, optional BIC behavior, QR eligibility for EUR + IBAN, and QR suppression for non-EUR or invalid/missing IBAN.
- Payment resolution tests should cover invoice override, Client preferred method, Workspace default fallback, deleted Client preference fallback, and missing/invalid default blocking.
- Invoice finalization tests should cover blocking on invalid Payment Method and not blocking on missing Tax/Legal Fields.
- Snapshot tests should verify finalized invoices preserve Tax/Legal Fields and selected Payment Method after Workspace, Client, or payment settings change.
- Migration tests should cover legacy paymentDetails with IBAN/BIC, legacy arbitrary payment text, legacy taxIdentifier/economicIdentifier, empty legacy fields, and existing production-like seed data.
- Archive tests should cover export/import of structured fields, legacy archive import, additive optional fields, invoice snapshot preservation, and validation of references.
- Render-context tests should cover placement-filtered field collections, canonical collections, empty section behavior, selected Payment Method fields, and QR data availability.
- Settings and Client UI tests should remain focused on high-value visible behavior only if needed; most logic should live in testable modules.
- Prior art includes existing workspace mutation tests, workspace projection tests, archive import/export validation tests, invoice PDF service tests, and payment QR tests.

## Out of Scope

- Tax calculation, tax filing, VAT return preparation, or legal compliance advice.
- Blocking invoice finalization because Billbi infers missing jurisdiction-specific tax identifiers.
- Validating Tax/Legal Field formats such as VAT ID, GSTIN, ABN, EIN, Steuernummer, or UID in v1.
- A full country-specific tax-status workflow such as VAT registered, reverse charge, B2B/B2C, or small-business exemption logic.
- Invoice-specific structured Tax/Legal Field editing in the create-invoice sheet.
- Saved legal note snippets or reusable tax note libraries.
- Full custom template editing, AI template editing, drag-and-drop layout, or user-authored template upload.
- Multiple visible Payment Methods on one v1 invoice.
- Payment processing, payment collection, transaction confirmation, bank connections, or paid-status automation.
- Crypto, UPI, or additional local payment rails as first-class v1 Payment Method types.
- Downloading or scraping live tax rules into the app.
- Treating preset suggestions as legal requirements.
- Archive v2 solely for this feature if additive v1 evolution can preserve compatibility.

## Further Notes

- ADR 0005 records the core trade-off: flexible non-blocking Tax/Legal Fields and typed validated Payment Methods.
- Billbi's domain glossary should remain the source of truth for terms. Use Client, not customer, in product and implementation language.
- The existing classic invoice template already has natural sender tax and payment footer slots; it can evolve toward dynamic collections without becoming a template builder.
- Payment validation is quality-of-life and invoice usefulness, not compliance. Tax/Legal Fields intentionally help without hindering.
- The feature should protect current production users by migrating existing flat business profile fields and continuing to import old archives.
- Preset sources should favor official government or primary business-registry/tax authority pages where possible, but the app copy should still frame presets as common suggestions rather than legal guarantees.
