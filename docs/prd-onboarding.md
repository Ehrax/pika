# PRD: First-Run Onboarding

## Problem Statement

Freelancers opening Billbi for the first time need a calm way to understand the app's Workspace model and optionally enter the basic information that makes future invoicing, clients, projects, and buckets feel grounded. Today the app can expose an empty workspace without explaining what the user should set up first, while invoice-critical details still need to be protected later when the user finalizes an Invoice.

## Solution

Build a skippable first-run onboarding flow shown as a full-window replacement before the normal app shell. The flow follows the high-fidelity onboarding designs in `docs/design-onboarding`, translated to native macOS SwiftUI and Billbi product copy.

Onboarding uses five visual steps: welcome, business setup, first client, first project with initial bucket, and ready summary. The flow can be skipped from any screen; skipping immediately marks onboarding complete for the Workspace and enters the app. Continue is always available and advances through the flow, but each step only saves meaningful entered data. Empty optional steps do not create placeholder records.

The setup ladder is progressive. A non-empty business name enables client setup. A non-empty client name creates a Client and enables project setup. A non-empty project name with a saved Client creates a Project and its initial Bucket, using `General` as the default bucket name when the user leaves the bucket blank. The ready screen summarizes only the setup data that actually exists and routes the user either to the created project workbench or to the dashboard.

Onboarding completion is stored in the Workspace data model, following ADR 0003, so completion follows workspace restore or sync. A debug-only menu bar action may reset only the completion flag for development and QA.

## User Stories

1. As a freelancer, I want Billbi to greet me with a focused first-run setup, so that I understand what the app helps me set up.
2. As a freelancer, I want onboarding to use Billbi branding, so that prototype names do not leak into the shipped app.
3. As a freelancer, I want onboarding to appear as the whole main window, so that I can focus on setup without the normal app shell competing for attention.
4. As a freelancer, I want native macOS window controls to remain available, so that the setup flow still feels like a Mac app.
5. As a freelancer, I want to skip setup from any onboarding screen, so that I can enter the app even when I do not have details ready.
6. As a freelancer, I want skipping setup to remember my choice, so that onboarding does not automatically appear again for the same Workspace.
7. As a freelancer, I want setup to run only once per Workspace, so that first-run guidance does not become recurring friction.
8. As a freelancer, I want any already-saved setup data to be kept when I skip later, so that partial setup work is not lost.
9. As a freelancer, I want Continue to always be available, so that I can click through the flow without being blocked by fields I do not know yet.
10. As a freelancer, I want empty optional steps not to create fake clients, projects, or buckets, so that my Workspace stays clean.
11. As a freelancer, I want completed onboarding steps to save immediately, so that quitting or skipping later does not discard useful setup data.
12. As a freelancer, I want the welcome screen to explain the setup chain, so that I understand the relationship between business details, clients, projects, and buckets.
13. As a freelancer, I want the welcome screen to be visual step one, so that the progress indicator matches the designed five-step flow.
14. As a freelancer, I want business setup to collect my basic business identity, so that Billbi has a grounded Workspace profile.
15. As a freelancer, I want business name to be enough to start setup, so that I can proceed even if I do not have every invoice detail ready.
16. As a freelancer, I want business email, address, currency, default hourly rate, and payment terms to be easy to enter, so that later invoices and projects start with sensible defaults.
17. As a freelancer, I want legal name, tax ID or VAT number, phone, website, and payment details to be optional, so that missing details do not block first-run setup.
18. As a freelancer, I want Billbi not to force country-specific tax setup during onboarding, so that the first-run flow stays globally approachable.
19. As a freelancer, I want the business step to show a live invoice header preview, so that I can see how my business identity will appear on invoices.
20. As a freelancer, I want the invoice header preview to update as I type, so that the effect of each field feels immediate.
21. As a freelancer, I want the preview invoice number to be clearly fake, so that I do not confuse onboarding preview copy with real invoice numbering.
22. As a freelancer, I want invoice numbering setup to remain outside onboarding for now, so that first-run setup stays lightweight.
23. As a freelancer, I want the first-client step to unlock only after I have started business setup, so that the setup chain remains understandable.
24. As a freelancer, I want client name to be enough to create a Client, so that I can set up work before I know every billing detail.
25. As a freelancer, I want client email, billing address, contact person, phone, VAT number, and rate override to be optional during onboarding, so that I can complete them later.
26. As a freelancer, I want the first-client step to show a lightweight client-list preview, so that I can see where the Client will live in the app.
27. As a freelancer, I want the first-client preview to use draft values before saving, so that I can inspect the result before Continue commits it.
28. As a freelancer, I want the first-project step to unlock only after a Client exists, so that Projects remain tied to Clients.
29. As a freelancer, I want project name to be enough to create a Project when a Client exists, so that setup does not require detailed planning.
30. As a freelancer, I want the first-project step to create an initial Bucket too, so that the Project is immediately usable for tracking and invoicing.
31. As a freelancer, I want Billbi to default the initial Bucket to General when I leave its name blank, so that the Project can still be usable without inventing a work-package name immediately.
32. As a freelancer, I want project currency and hourly rate to inherit from business defaults where possible, so that I do not repeat setup work.
33. As a freelancer, I want the project step to preview both the Project and initial Bucket, so that I understand the Project -> Bucket relationship.
34. As a freelancer, I want the ready screen to summarize only what I actually set up, so that the app does not imply records were created when I skipped or left steps blank.
35. As a freelancer, I want the ready screen to show business, client, project, and bucket cards only when those records or data exist, so that the summary stays truthful.
36. As a freelancer, I want the ready screen to route me to the project workbench when a Project and Bucket exist, so that I can continue from the setup I just created.
37. As a freelancer, I want the ready screen to route me to the dashboard when no Project and Bucket exist, so that I land in the most honest general destination.
38. As a freelancer, I want ready-screen tips to adapt to skipped setup data, so that the next suggestions match what I still need to do.
39. As a freelancer, I want tips to mention only features that exist or are part of this implementation, so that onboarding does not advertise unavailable settings.
40. As a freelancer, I want onboarding to avoid per-step skip buttons, so that I do not have to choose between too many exits.
41. As a freelancer, I want Back and Continue to be the main navigation controls, so that the flow feels simple and predictable.
42. As a freelancer, I want Return to trigger Continue where it does not conflict with text entry, so that keyboard use feels natural.
43. As a freelancer, I do not want Escape to skip setup, so that I do not permanently dismiss onboarding by accident.
44. As a freelancer, I want reopening the app mid-onboarding to restart at welcome, so that the flow stays simple.
45. As a freelancer, I want already-saved data to prefill when onboarding restarts, so that I do not retype setup information.
46. As a freelancer, I want invoice finalization to block later if required sender or recipient details are missing, so that lightweight onboarding does not let me send broken invoices.
47. As a freelancer, I want missing tax identifiers not to block onboarding, so that I can set up Billbi before knowing my final tax configuration.
48. As a developer, I want onboarding completion stored in Workspace data, so that restore and sync behavior are consistent.
49. As a developer, I want a debug-only menu bar action to reset onboarding completion, so that I can test first-run flows repeatedly.
50. As a developer, I want debug reset to preserve business profile data, Clients, Projects, Buckets, Invoices, and other records, so that testing onboarding does not destroy workspace data.
51. As a developer, I want onboarding forms to prefill from existing Workspace data after a debug reset, so that reset testing is fast and realistic.
52. As a developer, I want onboarding state transitions and save thresholds to be testable without UI tests, so that the behavior remains stable as the SwiftUI design evolves.

## Implementation Decisions

- Add Workspace-scoped onboarding completion state, following ADR 0003.
- Extend persistence, projections, archive/restore shape, and seed/default Workspace construction so onboarding completion survives normal Workspace loading, restoring, and syncing.
- Add app-facing WorkspaceStore commands for completing onboarding, resetting onboarding completion in debug builds, and saving onboarding step data with relaxed thresholds.
- Do not reuse the existing strict business profile update command directly for onboarding unless it is refactored to support partial setup safely. Current settings-style profile validation is stricter than onboarding.
- Introduce an onboarding flow model as a deep module that owns step progression, unlock rules, save thresholds, ready-screen summary decisions, and contextual CTA decisions.
- Keep SwiftUI onboarding views presentation-focused. Views should render draft state, previews, controls, and call WorkspaceStore/onboarding-flow commands rather than owning domain decisions.
- Present onboarding as a full-window replacement before the normal app shell and navigation are shown.
- Keep normal macOS window controls native while rendering an onboarding-specific top bar with Billbi branding, progress, and Skip setup.
- Use the designs in `docs/design-onboarding` as high-fidelity wireframes, translated to macOS-native SwiftUI and Billbi copy.
- Replace all prototype Pika branding in implementation copy with Billbi.
- Preserve the five visual steps: welcome, business, first client, first project with initial bucket, and ready.
- Continue always advances. It should save meaningful data when thresholds are met and avoid creating placeholder records when thresholds are not met.
- Skip setup always persists onboarding completion immediately and enters the app.
- A non-empty business name unlocks the client step.
- A non-empty client name creates a Client and unlocks the project step.
- A non-empty project name with a saved Client creates the Project and its initial Bucket.
- The initial Bucket default name is General when the user leaves the bucket field blank.
- Project currency and hourly rate inherit from business defaults when possible.
- The business step includes a header-only live invoice preview driven by draft values.
- The header preview uses PREVIEW-001 and does not expose invoice numbering setup.
- The first-client step includes a lightweight draft-driven client-list preview.
- The first-project step includes a draft-driven project and initial bucket preview.
- The ready screen is a summary and handoff, not a live product preview.
- Ready summary cards render only existing setup data.
- Ready primary CTA opens the project workbench when a Project and Bucket exist; otherwise it goes to the dashboard.
- Ready tips adapt to missing setup data and should not mention unavailable features such as brand color selection.
- Add a debug-only menu command to clear onboarding completion without deleting Workspace records.
- If the app quits mid-onboarding, do not persist step position. Restart at welcome and prefill from saved Workspace data.
- Use existing active projection order when prefilling from existing clients or projects; do not introduce special ranking for v1.

## Testing Decisions

- Test external behavior and domain thresholds rather than SwiftUI implementation details.
- Unit test the onboarding flow model for step progression, unlock rules, save thresholds, skip behavior, ready-summary card decisions, and CTA selection.
- Unit test WorkspaceStore onboarding commands for saving partial business profile data, creating Clients only when a client name exists, creating Projects and initial Buckets only when prerequisites exist, and avoiding placeholder records.
- Unit test onboarding completion persistence in Workspace snapshots and normalized persistence.
- Unit test debug reset behavior to ensure it clears only onboarding completion and preserves business profile data, Clients, Projects, Buckets, Invoices, and Activity.
- Add archive/restore coverage if the Workspace Archive format changes for onboarding completion.
- Add focused macOS UI tests or launch checks for first-run presentation, skip entering the app, completed flow entering the app, and debug reset re-showing onboarding.
- Use existing WorkspaceStore mutation tests, projection tests, archive tests, and UI launch checks as prior art.
- For visual polish, verify the onboarding screens manually or with screenshots across representative macOS window sizes against the high-fidelity wireframes.

## Out of Scope

- Country-specific tax setup, VAT-status workflows, exemption-note configuration, reverse-charge handling, and per-project tax compliance.
- Full invoice template selection during onboarding.
- Real invoice numbering setup during onboarding.
- Brand color/logo customization during onboarding.
- Bank connection, paid-status automation, or payment reconciliation setup.
- Auto-starting a timer or creating a time entry from the ready screen.
- A production user-facing way to re-run onboarding after completion or skip.
- Deleting workspace data from the debug onboarding reset.
- Creating Projects without Clients.
- Creating placeholder Clients, Projects, or Buckets for empty onboarding steps.
- Changing the broader invoicing readiness rules beyond ensuring missing invoice-required details can still block invoice finalization later.

## Further Notes

- The source designs live in `docs/design-onboarding` and should be treated as high-fidelity wireframes, not exact web layouts. The implementation should remain native to macOS SwiftUI.
- The product is Billbi. Pika was an early prototype name and should not appear in shipped onboarding copy.
- The final ready screen redesign removes the timer preview. It should show setup cards, contextual navigation, and lightweight tips.
- Swiss and German invoice research informed the decision to keep onboarding globally minimal and defer jurisdiction-specific validation to later configuration.
- The current project creation path creates a first Bucket as part of Project creation, which aligns with the onboarding decision to create an initial Bucket when a first Project is created.
