# SwiftData Data Overhaul (No Migration)

## Decision

- Persistence backend is now SwiftData-only for workspace runtime state.
- CloudKit/iCloud sync is intentionally disabled (`cloudKitDatabase: .none`) for deterministic local-first behavior during this phase.

## Persistence Architecture

- `WorkspaceStore` now persists through SwiftData `ModelContext`.
- `WorkspaceStorageRecord` is the persisted SwiftData model root for workspace state.
- App runtime uses a file-backed SwiftData store at `Application Support/Pika/workspace.store`.
- In-memory store contexts are still used for isolated unit test defaults.

## JSON Removal Scope

Removed from app persistence logic:

- `workspace.json` default path construction.
- direct file IO read/write persistence (`Data(contentsOf:)`, `data.write(to:)`).
- JSON encoder/decoder persistence path in `WorkspaceStore`.
- app launch persistence URL override contract (`--pika-workspace-path`) from runtime configuration.

## CloudKit Config

- `PikaApp.makeModelContainer`: `cloudKitDatabase: .none`
- `WorkspaceStore.makeModelContainer`: `cloudKitDatabase: .none`

Rationale:

- Keeps persistence deterministic while the new SwiftData storage path stabilizes.
- Avoids accidental sync/schema side effects during local-first refactor validation.
- Allows adding CloudKit later behind explicit product + schema decisions.
