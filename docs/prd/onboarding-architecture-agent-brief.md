# Agent Brief: Onboarding Architecture Deepening

## Agent Brief

**Category:** enhancement
**Summary:** Deepen onboarding architecture with TDD so flow decisions, ready handoff, and relaxed Workspace setup rules are tested through public interfaces.

**Current behavior:**
The onboarding flow works, but important behaviour is spread across presentation, flow state, and Workspace commands. The `OnboardingFlowModel` interface currently exposes step progression and partial ready-summary behaviour, while the SwiftUI onboarding view still owns Continue handling, save thresholds, Client-to-Project handoff logic, ready-screen copy, tips, and completion handoff. Workspace onboarding commands support relaxed setup, but some relaxed rules may have leaked into normal Client and Project creation commands.

This makes onboarding harder to safely refactor because behaviour is not concentrated behind one deep module interface.

**Desired behavior:**
Onboarding should be driven by a deeper flow module interface and verified with vertical TDD slices. Presentation should render flow decisions rather than own setup ladder rules. Workspace onboarding commands should preserve onboarding's relaxed thresholds without accidentally changing unrelated normal Workspace behaviour.

The onboarding product behaviour should stay the same:

- Continue advances through welcome, business, client, project, and ready.
- Business setup saves only meaningful business data.
- First Client setup creates a real Client only when a Client name exists.
- First Project setup creates a real Project only when a Project name and saved Client exist.
- Blank first Bucket names become `General` for onboarding-created Projects.
- Empty optional steps do not create placeholder Clients, Projects, or Buckets.
- Skipping setup completes onboarding and opens the Dashboard.
- Finishing setup completes onboarding and opens the created Project workbench when a Project and Bucket exist; otherwise it opens the Dashboard.
- Onboarding completion remains durable Workspace state and debug reset clears only completion.

**Key interfaces:**

- `OnboardingFlowModel` — should expose the public onboarding flow decisions: step progression, Continue decision, ready summary, and primary CTA.
- `OnboardingPrimaryCTA` — should represent Dashboard handoff or Project workbench handoff with both Project and Bucket identifiers.
- `OnboardingReadySummary` or equivalent — should consolidate ready cards, badge state, title, subtitle, tips, and primary CTA into one testable value.
- `OnboardingContinueAction` or equivalent — should represent what Continue means for the current step: advance only, save business, save Client, save Project, complete onboarding.
- `WorkspaceStore` onboarding commands — should remain the app-facing commands for completion, debug reset, and onboarding-specific saving of business, first Client, and first Project with initial Bucket.
- Normal Workspace Client and Project creation commands — should keep their intended public validation behaviour unless this work explicitly confirms the relaxed rules are desired globally.

**Acceptance criteria:**

- [ ] A behaviour test proves ready handoff returns a Project CTA when the Workspace has an active Project with a first Bucket.
- [ ] A behaviour test proves ready handoff returns Dashboard when no Project and Bucket exist.
- [ ] Ready summary behaviour is exposed through one tested flow-module value, including cards, badge state, title/subtitle, tips, and CTA.
- [ ] Continue behaviour is tested through a public flow interface rather than by relying on SwiftUI implementation details.
- [ ] SwiftUI onboarding presentation no longer owns the Client -> Project -> Bucket setup ladder rules.
- [ ] Onboarding-specific Workspace commands still allow name-only Client creation and `General` first Bucket defaulting.
- [ ] Normal Client and Project creation behaviour is either preserved or explicitly covered by tests if the product decision is to relax it globally.
- [ ] Completion persistence tests still prove normalized reload keeps onboarding completion.
- [ ] Debug reset tests still prove only onboarding completion is cleared.
- [ ] Archive import/export tests prove onboarding completion is preserved.
- [ ] The focused macOS unit gate passes with `./script/test.sh`.
- [ ] Verified local launches pass for empty and seeded workspaces after presentation splitting.

**Out of scope:**

- Redesigning onboarding screens or changing copy for visual polish.
- Adding country-specific tax setup or invoice-template selection.
- Adding a production user-facing rerun onboarding action.
- Replacing `WorkspaceStore` with a reducer, event hub, or broader architecture rewrite.
- Changing invoice finalization readiness rules beyond preserving the current onboarding contract.
- Adding UI tests for every visual step unless a behaviour cannot be protected through unit or integration-style tests.

**Execution notes:**

Use the companion PRD, `docs/prd/onboarding-architecture-deepening.md`, for the recommended red-green-refactor slice order. Work one vertical slice at a time: write one behaviour test, watch it fail for the expected reason, implement the smallest green change, then refactor while green.
