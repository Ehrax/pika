# Pika Context

## Domain Language

- **Workspace**: the app-facing model of a freelancer's invoicing world. It includes the business profile, clients, projects, buckets, invoices, and activity visible to the app.
- **Client**: a billable customer with contact, billing address, payment terms, and archive state.
- **Project**: a body of work for a client. A project contains buckets and finalized invoices.
- **Bucket**: a project work package that collects time entries and fixed costs before it is ready to invoice.
- **Invoice**: a finalized billing document created from an invoiceable bucket. Its business, client, project, bucket, line-item, and status details are snapshotted at finalization time.
- **Activity**: a local audit-style event shown in the app for notable workspace changes.

## Architecture Language

- **Workspace Module**: the app-facing module that SwiftUI uses to read workspace state and issue workspace commands.
- **WorkspaceStore**: the observable coordinator for the Workspace Module. It should expose stable app-facing commands while delegating persistence, projections, and invoicing decisions to deeper modules.
- **WorkspacePersistence**: the module that owns SwiftData, CloudKit-compatible normalized records, seed import, save, load, and reload behavior. `ModelContext` should stay hidden behind this module instead of flowing through views or domain workflow.
- **WorkspaceProjections**: the module that builds dashboard, project, bucket, and invoice read models from workspace data.
- **WorkspaceInvoicingWorkflow**: the production-used module that owns invoice readiness, finalization, and invoice status workflow decisions.
- **WorkspaceSnapshot**: the app-facing read model/cache that SwiftUI can render efficiently. It should stay separate from SwiftData normalized records, which remain the durable persistence shape.

## Current Architecture Direction

- Keep `WorkspaceStore` as Pika's app-facing Workspace Module for now.
- Deepen its implementation rather than replacing it with a Redux-style reducer or a Flutter BLoC-style event hub.
- Treat SwiftData plus private CloudKit as load-bearing persistence.
- Inject `ModelContext` at app composition time, then keep it inside `WorkspacePersistence`.
- Keep SwiftUI views focused on local presentation state, projections, and calls to `WorkspaceStore` commands.
- Keep Pika MV-first for SwiftUI. Use lightweight DDD-informed layering only to name where domain decisions live:
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
