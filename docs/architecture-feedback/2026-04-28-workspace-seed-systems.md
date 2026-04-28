# Workspace Seed Systems Feedback (2026-04-28)

## Context

We currently have multiple seed-like pathways for `WorkspaceSnapshot`, and they overlap in purpose.

## Current Seed Systems

1. `WorkspaceSnapshot.empty`
- File: `pika/Models/WorkspaceSnapshot.swift`
- Role: true empty/default workspace model.

2. `WorkspaceSnapshot.sample`
- File: `pika/Models/WorkspaceSnapshot+SampleData.swift`
- Role: generic demo/fake data (`Happ.ines`, `Northstar`, `Acme`, sample invoices/activity/dashboard).

3. `WorkspaceSnapshot.bikeparkThunersee`
- File: `pika/Models/WorkspaceSnapshot+SampleData.swift`
- Role: client-specific/working-like data; not generic demo seed.

4. App launch seed selection
- File: `pika/App/AppDependencyGraph.swift`
- Inputs: `--pika-seed-workspace`, `--pika-seed-bikepark-thunersee`, `PIKA_SEED_WORKSPACE`.

5. Script/Codex seed modes
- Files: `script/build_and_run.sh`, `.codex/environments/environment.toml`
- Modes: `Play Empty`, `Play Seeded`, `Play Bikepark`.

## Concrete Smell

`script/build_and_run.sh` supports `--empty`, but in `DEBUG` the app defaults to `.bikeparkThunersee` when no seed flag is passed (`pika/App/AppDependencyGraph.swift`).

Risk:
- `Play Empty` can launch Bikepark data, which violates developer expectation and can mask regressions.

## Test Fixture Coupling Smell

`pikaTests/WorkspaceSnapshotTests.swift` and related tests rely heavily on `WorkspaceSnapshot.sample` and partial workspaces derived from it (`sample.businessProfile`, `sample.clients`).

Risk:
- Demo data and tests are tightly coupled.
- Small demo-data changes can create brittle test failures unrelated to behavior.

## Suggested Refactor Direction

Proposed structure:

```text
pika/Development/
  WorkspaceSeed.swift
  WorkspaceSeedLibrary.swift

pikaTests/Fixtures/
  WorkspaceFixtures.swift
```

Proposed single seed enum:

```swift
enum WorkspaceSeed: String {
    case empty
    case sample
    case bikeparkThunersee
}
```

Then route all entry points through that enum:
- app launch args
- environment vars
- scripts
- previews
- tests

Additional recommendations:
- Rename `sample` to `demoWorkspace` for clarity.
- Treat `bikeparkThunersee` as private/dev-only seed data.
- Avoid using client-specific data as implicit/default launch state.
- Move test-specific workspaces to `pikaTests/Fixtures`.

## Decision Notes

This is architecture feedback, not a behavior change yet.

When implementing:
- decide whether default debug launch should be `.empty` or `.sample` (not `.bikeparkThunersee`),
- migrate tests to dedicated fixtures first,
- then simplify seed selection and script flags.



---

## Status

Implemented on 2026-04-28 in the seed cleanup branch:
- app seed selection now routes through `pika/Development/WorkspaceSeed.swift`,
- demo and Bikepark seed data now live in `pika/Development/WorkspaceSeedLibrary.swift`,
- test code now uses `pikaTests/Fixtures/WorkspaceFixtures.swift`,
- app debug launch defaults to `.empty`,
- script/Codex seed modes route through the unified seed argument.

The broader responsibilities-per-file feedback remains tracked separately in:
- docs/architecture-feedback/2026-04-28-responsibilities-per-file-debt.md
