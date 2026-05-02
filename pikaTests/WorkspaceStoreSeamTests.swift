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
    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {}
    func save() throws {}
}

private final class CapturingPersistenceAdapter: WorkspacePersistenceAdapter {
    private(set) var replacedSnapshots: [WorkspaceSnapshot] = []

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        replacedSnapshots.append(snapshot)
    }

    func save() throws {}
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

    func ensureBucketCanBeRemoved(status: BucketStatus) throws {
        guard status == .archived else {
            throw WorkspaceStoreError.bucketLocked(status)
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

private struct RejectArchivedBucketRemovalPolicy: WorkspaceMutationPolicy {
    private let fallback = DefaultWorkspaceMutationPolicy()

    func ensureBucketCanBeMarkedReady(_ bucket: WorkspaceBucket) throws {
        try fallback.ensureBucketCanBeMarkedReady(bucket)
    }

    func ensureBucketStatusTransition(from currentStatus: BucketStatus, to targetStatus: BucketStatus) throws {
        try fallback.ensureBucketStatusTransition(from: currentStatus, to: targetStatus)
    }

    func ensureBucketCanBeRemoved(status: BucketStatus) throws {
        if status == .archived {
            throw WorkspaceStoreError.bucketLocked(.archived)
        }
        try fallback.ensureBucketCanBeRemoved(status: status)
    }

    func ensureInvoiceStatusTransition(from sourceStatus: InvoiceStatus, to targetStatus: InvoiceStatus) throws {
        try fallback.ensureInvoiceStatusTransition(from: sourceStatus, to: targetStatus)
    }
}

struct WorkspaceStoreSeamTests {
    @Test func defaultMutationPolicyCoversReadyFinalizedArchivedLockedAndRemovableBucketCases() throws {
        let policy = DefaultWorkspaceMutationPolicy()

        let openInvoiceableBucket = WorkspaceBucket(
            id: UUID(),
            name: "Invoiceable",
            status: .open,
            totalMinorUnits: 10_000,
            billableMinutes: 60,
            fixedCostMinorUnits: 0
        )
        try policy.ensureBucketCanBeMarkedReady(openInvoiceableBucket)

        let finalizedBucket = WorkspaceBucket(
            id: UUID(),
            name: "Finalized",
            status: .finalized,
            totalMinorUnits: 10_000,
            billableMinutes: 60,
            fixedCostMinorUnits: 0
        )
        #expect(throws: WorkspaceStoreError.bucketNotInvoiceable) {
            try policy.ensureBucketCanBeMarkedReady(finalizedBucket)
        }

        try policy.ensureBucketStatusTransition(from: .open, to: .archived)
        try policy.ensureBucketStatusTransition(from: .archived, to: .open)

        #expect(throws: WorkspaceStoreError.bucketLocked(.finalized)) {
            try policy.ensureBucketStatusTransition(from: .finalized, to: .archived)
        }
        #expect(throws: WorkspaceStoreError.bucketLocked(.ready)) {
            try policy.ensureBucketStatusTransition(from: .ready, to: .open)
        }

        try policy.ensureBucketCanBeRemoved(status: .archived)
        #expect(throws: WorkspaceStoreError.bucketLocked(.ready)) {
            try policy.ensureBucketCanBeRemoved(status: .ready)
        }
    }

    @Test func workspacePersistenceNormalizesSeedImportBeforeDelegatingToAdapter() throws {
        let modelContainer = try WorkspaceStore.makeModelContainer(mode: .inMemory)
        let modelContext = ModelContext(modelContainer)
        let persistenceAdapter = CapturingPersistenceAdapter()
        let persistence = DefaultWorkspacePersistence(
            modelContext: modelContext,
            usesNormalizedPersistence: true,
            projectionLoadingAdapter: EmptyProjectionLoader(),
            persistenceAdapter: persistenceAdapter
        )
        var seed = WorkspaceFixtures.demoWorkspace
        seed.projects[0].buckets[0].timeEntries[0].hourlyRateMinorUnits = 0

        try persistence.replacePersistentWorkspaceWithSeedImport(seed)

        let importedSnapshot = try #require(persistenceAdapter.replacedSnapshots.first)
        #expect(importedSnapshot.projects[0].buckets[0].timeEntries[0].hourlyRateMinorUnits == 20_000)
    }

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

    @Test func mutationPolicyCanOverrideArchivedBucketRemovalRule() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009998")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009998")!
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Policy Project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Archived Bucket",
                            status: .archived,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )
        let store = WorkspaceStore(seed: workspace, mutationPolicy: RejectArchivedBucketRemovalPolicy())

        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try store.removeBucket(projectID: projectID, bucketID: bucketID)
        }
    }
}
