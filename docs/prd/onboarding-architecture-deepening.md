# PRD: Onboarding Architecture Deepening

## Problem

The onboarding PR works, but much of the onboarding behaviour sits in shallow places.
`OnboardingFlowModel` exists, but SwiftUI still owns important Workspace setup decisions: when Continue saves data, how the first Client enables the first Project, how the first Bucket default is chosen, what the ready screen summarizes, and where the primary handoff should navigate.

This makes the onboarding flow harder to test through one public interface, and it spreads the Client -> Project -> Bucket setup ladder across the view and `WorkspaceStore`.

## Goal

Deepen the onboarding modules without changing the intended product behaviour:

- Onboarding remains a skippable first-run setup helper.
- Continue always advances through the five visual steps.
- Each completed setup step saves meaningful real Workspace data immediately.
- Empty optional steps do not create placeholder Clients, Projects, or Buckets.
- The ready screen summarizes only setup data that really exists.
- The primary ready action opens the created Project workbench when a Project and Bucket exist; otherwise it opens the Dashboard.
- Onboarding completion remains Workspace-scoped durable state, following ADR 0003.

## Non-Goals

- Do not redesign the onboarding screens.
- Do not add country-specific invoice or tax setup.
- Do not add a production way to rerun onboarding.
- Do not replace `WorkspaceStore` with a reducer or new application architecture.
- Do not broaden normal Client or Project creation rules unless a TDD slice proves that is the intended public Workspace behaviour.

## Public Interfaces To Shape

### Onboarding Flow Module

`OnboardingFlowModel` should become the main public interface for onboarding flow decisions.
Callers should be able to ask it for:

- current step
- next/back progression
- whether a step has meaningful data to save
- which Workspace command should run for Continue on the current step
- ready summary cards
- ready title, subtitle, tips, and badge state
- ready primary CTA

The SwiftUI view should render this interface and dispatch user intentions. It should not know the setup ladder rules.

### Workspace Module Onboarding Commands

`WorkspaceStore` should keep onboarding-specific commands for:

- completing onboarding
- debug-resetting onboarding completion
- saving onboarding business setup
- saving onboarding first Client
- saving onboarding first Project with initial Bucket

These commands should protect onboarding's relaxed thresholds without accidentally changing unrelated normal Workspace command behaviour.

### Onboarding Presentation Modules

`OnboardingView` should become a small root view that wires draft state, flow state, and Workspace commands.
Step views, previews, form rows, ready summary, and layout primitives should live beside it as focused feature files.

## TDD Plan

Work in vertical red-green-refactor slices. Do not write all tests first.

### Slice 1: Ready CTA Opens Created Project

Behavior test:

- Given a Workspace with a saved Project and first Bucket, the onboarding ready projection returns `.project(projectID:bucketID:)`.
- Given no Project and Bucket, the ready projection returns `.dashboard`.

Expected first red:

- The current `OnboardingFlowModel.primaryCTA(for:)` always returns `.dashboard`.

Minimal green:

- Make the flow module choose the first active Project with a first Bucket.

Refactor:

- Rename the tested surface to something like `readySummary(for:)` only if the next slice needs a deeper return type.

### Slice 2: Ready Summary Is One Tested Projection

Behavior test:

- Given only business setup, the ready projection returns only the business card, business-specific subtitle, and tips for adding Clients and Projects.
- Given business, Client, Project, and Bucket, it returns all real cards, a Project-specific subtitle, Project-specific tips, and a Project CTA.
- Given skipped setup, it returns no cards, neutral/skipped state, Dashboard CTA, and tips that do not imply placeholder records exist.

Minimal green:

- Move ready badge, title, subtitle, tips, cards, and CTA behind one `OnboardingReadySummary` value returned by the flow module.

Refactor:

- Replace repeated `OnboardingFlowModel.summaryCards(for:)` calls in SwiftUI with the single ready summary value.

### Slice 3: Continue Decisions Leave SwiftUI

Behavior test:

- From welcome, Continue advances without saving.
- From business, Continue requests a business save only when the business name is non-empty, then advances.
- From client, Continue requests a Client save only when the Client name is non-empty, then advances.
- From project, Continue requests Project creation only when a Project name and saved Client exist, then advances.
- From ready, Continue completes onboarding and returns the ready CTA.

Minimal green:

- Introduce a small flow decision value such as `OnboardingContinueAction`.
- `OnboardingView` switches on that value and calls the relevant Workspace command, but no longer owns the ladder rules.

Refactor:

- Remove `savedClientID` fallback logic from the view if the flow decision can derive the effective Client from current Workspace and drafts.

### Slice 4: Onboarding Workspace Commands Do Not Loosen Normal Commands By Accident

Behavior test:

- Onboarding can create a Client with only a name.
- Normal Client creation keeps its intended public validation behaviour.
- Onboarding can create a Project with a blank Bucket name and gets a `General` Bucket.
- Normal Project creation keeps its intended public validation behaviour.

Minimal green:

- If current normal command relaxation is accidental, move relaxed thresholds into onboarding commands only.
- If current normal command relaxation is intended product behaviour, document it in the test name and keep it explicit.

Refactor:

- Extract shared trimming/defaulting helpers only when they remove duplication without creating a shallow pass-through module.

### Slice 5: Presentation Split Without Behaviour Change

Behavior test:

- No new logic test is required for file splitting if Slice 1-4 tests cover the behaviour.
- Run the focused unit gate after each extraction.

Minimal green:

- Extract one step at a time from `OnboardingView`.
- Preserve the existing public view interface.

Suggested extraction order:

1. `OnboardingReadyView`
2. `OnboardingBusinessStepView`
3. `OnboardingClientStepView`
4. `OnboardingProjectStepView`
5. `OnboardingWelcomeStepView`
6. `OnboardingPreviewPanel`
7. `OnboardingFormField`
8. `OnboardingFixedSplit`

Refactor:

- Keep the root `OnboardingView` responsible only for composition, draft state, errors, and invoking Workspace commands selected by the flow module.

### Slice 6: Completion Persistence Locality

Behavior test:

- Completing onboarding persists through normalized Workspace reload.
- Debug reset clears only onboarding completion and preserves business profile, Clients, Projects, Buckets, Invoices, and Activity.
- Workspace archive export/import preserves onboarding completion.

Minimal green:

- Keep existing behaviour green.
- If the mapping remains scattered, create a focused persistence mapping module or extension for onboarding completion.

Refactor:

- Make `WorkspaceStore` issue onboarding completion commands while persistence owns SwiftData/archive/snapshot mapping details.

## Verification

Run after each green slice:

```sh
./script/test.sh
```

Run when presentation splitting is complete:

```sh
./script/build_and_run.sh --verify --empty --local
./script/build_and_run.sh --verify --seeded --local
```

Add screenshot or manual notes only for visual polish changes. The main protection should come from behaviour tests through public interfaces.

## Open Decisions

- Should normal Client creation now allow name-only Clients, or is that onboarding-specific leniency?
- Should normal Project creation now default a blank first Bucket to `General`, or is that onboarding-specific leniency?
- Should the ready summary choose the first active Project by existing projection order, or should it prefer the Project created during the current onboarding run?
