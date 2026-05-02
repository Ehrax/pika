import Foundation
import SwiftData
import Testing
@testable import pika

private struct EmptyProjectionLoader: WorkspaceProjectionLoadingAdapter {
    func loadNormalizedWorkspace(from context: ModelContext) -> WorkspaceSnapshot? {
        nil
    }
}

private struct NoopPersistenceAdapter: WorkspacePersistenceAdapter {
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot, in context: ModelContext) throws {}
    func save(context: ModelContext) throws {}
}

private final class RecordingWorkspacePersistence: WorkspacePersistence {
    private(set) var bootSeed: WorkspaceSnapshot?
    private(set) var bootResetForSeedImport = false
    private(set) var saveAndReloadActivity: [WorkspaceActivity] = []
    private(set) var saveAndReloadCallCount = 0
    private let bootWorkspace: WorkspaceSnapshot
    private let reloadedWorkspace: WorkspaceSnapshot

    init(bootWorkspace: WorkspaceSnapshot, reloadedWorkspace: WorkspaceSnapshot) {
        self.bootWorkspace = bootWorkspace
        self.reloadedWorkspace = reloadedWorkspace
    }

    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot {
        bootSeed = seed
        bootResetForSeedImport = resetForSeedImport
        return bootWorkspace
    }

    func isUsingNormalizedPersistence() -> Bool {
        true
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {}

    func persistWorkspace() throws {}

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        saveAndReloadCallCount += 1
        saveAndReloadActivity = activity
        var reloaded = reloadedWorkspace
        reloaded.activity = activity
        return reloaded
    }
}

private struct RejectPaidInvoicePolicy: WorkspaceMutationPolicy {
    func ensureBucketCanBeMarkedReady(_ bucket: WorkspaceBucket) throws {
        if bucket.status != .open || bucket.effectiveTotalMinorUnits <= 0 {
            throw WorkspaceStoreError.bucketNotInvoiceable
        }
    }

    func ensureBucketStatusTransition(from currentStatus: BucketStatus, to targetStatus: BucketStatus) throws {
        switch targetStatus {
        case .archived:
            guard !currentStatus.isInvoiceLocked else {
                throw WorkspaceStoreError.bucketLocked(currentStatus)
            }
        case .open:
            guard currentStatus == .archived else {
                throw WorkspaceStoreError.bucketLocked(currentStatus)
            }
        case .ready, .finalized:
            throw WorkspaceStoreError.bucketStatusNotReady(currentStatus)
        }
    }

    func ensureInvoiceStatusTransition(from sourceStatus: InvoiceStatus, to targetStatus: InvoiceStatus) throws {
        if targetStatus == .paid {
            throw WorkspaceStoreError.invalidInvoiceStatusTransition(from: sourceStatus, to: targetStatus)
        }
        guard InvoiceWorkflowPolicy.canTransition(from: sourceStatus, to: targetStatus) else {
            throw WorkspaceStoreError.invalidInvoiceStatusTransition(from: sourceStatus, to: targetStatus)
        }
    }
}

struct WorkspaceStoreSeamTests {
    @Test func workspaceStoreUsesWorkspacePersistenceForBootAndReload() throws {
        let seed = WorkspaceFixtures.demoWorkspace
        var bootWorkspace = WorkspaceSnapshot.empty
        bootWorkspace.businessProfile.businessName = "Booted Workspace"
        var reloadedWorkspace = WorkspaceSnapshot.empty
        reloadedWorkspace.businessProfile.businessName = "Reloaded Workspace"
        let persistence = RecordingWorkspacePersistence(
            bootWorkspace: bootWorkspace,
            reloadedWorkspace: reloadedWorkspace
        )
        let store = WorkspaceStore(
            seed: seed,
            workspacePersistence: persistence
        )

        #expect(store.workspace.businessProfile.businessName == "Booted Workspace")
        #expect(
            persistence.bootSeed?.businessProfile.businessName ==
                seed.businessProfile.businessName
        )
        #expect(persistence.bootResetForSeedImport == false)

        store.workspace.activity = [
            WorkspaceActivity(
                message: "Keep me",
                detail: "Across reload",
                occurredAt: Date(timeIntervalSince1970: 1_777_777_777)
            ),
        ]

        try store.saveAndReloadNormalizedWorkspacePreservingActivity()

        #expect(store.workspace.businessProfile.businessName == "Reloaded Workspace")
        #expect(store.workspace.activity.map { $0.message } == ["Keep me"])
        #expect(persistence.saveAndReloadCallCount == 1)
        #expect(persistence.saveAndReloadActivity.map { $0.detail } == ["Across reload"])
    }

    @Test func projectionLoadingAdapterFallbackUsesSeedWhenNoPersistedWorkspaceExists() throws {
        let seed = WorkspaceFixtures.demoWorkspace
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
        let store = WorkspaceStore(
            seed: seed,
            modelContext: modelContext,
            projectionLoadingAdapter: EmptyProjectionLoader(),
            persistenceAdapter: NoopPersistenceAdapter()
        )

        #expect(store.workspace.businessProfile.businessName == seed.businessProfile.businessName)
        #expect(store.workspace.clients.count == seed.clients.count)
    }

    @Test func mutationPolicyCanOverrideInvoiceTransitions() throws {
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000009999")!
        var workspace = WorkspaceFixtures.demoWorkspace
        workspace.projects = [
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000009999")!,
                name: "Policy Project",
                clientName: "Happ.ines",
                currencyCode: "EUR",
                isArchived: false,
                buckets: [],
                invoices: [
                    WorkspaceInvoice(
                        id: invoiceID,
                        number: "EHX-2026-999",
                        clientName: "Happ.ines",
                        issueDate: .now,
                        dueDate: .now,
                        status: .finalized,
                        totalMinorUnits: 10_000
                    ),
                ]
            ),
        ]

        let store = WorkspaceStore(seed: workspace, mutationPolicy: RejectPaidInvoicePolicy())
        #expect(throws: WorkspaceStoreError.invalidInvoiceStatusTransition(from: .finalized, to: .paid)) {
            try store.markInvoicePaid(invoiceID: invoiceID)
        }
    }
}
