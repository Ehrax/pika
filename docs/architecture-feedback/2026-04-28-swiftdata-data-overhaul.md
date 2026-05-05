# SwiftData Data Overhaul (No Migration)

## Decision

- Persistence backend is SwiftData-only with normalized records as the source of truth.
- Default runtime persistence uses private CloudKit sync.
- Pre-release workspace persistence is intentionally no-migration for legacy blob/plist data.

## Persistence Architecture

- `WorkspaceStore` now persists through SwiftData `ModelContext`.
- The normalized model graph (`BusinessProfileRecord`, `ClientRecord`, `ProjectRecord`, `BucketRecord`, `TimeEntryRecord`, `FixedCostRecord`, `InvoiceRecord`, `InvoiceLineItemRecord`) is the persisted source of truth.
- Seed-based deterministic imports replace existing local normalized records when explicitly requested.
- In-memory contexts remain the default for isolated tests.

## Legacy Removal Scope

Removed from app persistence logic:

- `workspace.json` default path construction.
- direct file IO read/write persistence (`Data(contentsOf:)`, `data.write(to:)`).
- JSON encoder/decoder persistence path in `WorkspaceStore`.
- blob/plist workspace persistence (`WorkspaceStorageRecord`, binary plist payload encode/decode).
- legacy workspace path migration and cleanup behavior.

## CloudKit Config

- `AppPersistenceMode.cloudKitPrivate` uses:
  - `cloudKitDatabase: .private("iCloud.ehrax.dev.billbi")`
- `AppPersistenceMode.local` and `AppPersistenceMode.inMemory` use:
  - `cloudKitDatabase: .none`

Rationale:

- Keeps the default app experience synced privately across the developer's devices.
- Preserves deterministic local/test behavior for seed imports and automated tests.
- Avoids carrying pre-release migration debt for superseded blob storage formats.
