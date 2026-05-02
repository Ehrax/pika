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
    func applyInvoiceFinalizationResult(_ result: InvoiceFinalizationResult) throws {}
    func save() throws {}
    func rollback() {}
}

private final class CapturingPersistenceAdapter: WorkspacePersistenceAdapter {
    private(set) var replacedSnapshots: [WorkspaceSnapshot] = []

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        replacedSnapshots.append(snapshot)
    }

    func applyInvoiceFinalizationResult(_ result: InvoiceFinalizationResult) throws {}

    func save() throws {}

    func rollback() {}
}

private final class SaveFailingPersistenceAdapter: WorkspacePersistenceAdapter {
    enum Failure: Error {
        case saveFailed
    }

    private(set) var applyCallCount = 0
    private(set) var rollbackCallCount = 0

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {}

    func applyInvoiceFinalizationResult(_ result: InvoiceFinalizationResult) throws {
        applyCallCount += 1
    }

    func save() throws {
        throw Failure.saveFailed
    }

    func rollback() {
        rollbackCallCount += 1
    }
}

private final class SaveSucceedingPersistenceAdapter: WorkspacePersistenceAdapter {
    private(set) var applyCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var rollbackCallCount = 0

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {}

    func applyInvoiceFinalizationResult(_ result: InvoiceFinalizationResult) throws {
        applyCallCount += 1
    }

    func save() throws {
        saveCallCount += 1
    }

    func rollback() {
        rollbackCallCount += 1
    }
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

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot {
        reloadedWorkspace
    }

    func persistWorkspace() throws {}

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        saveAndReloadCallCount += 1
        saveAndReloadActivity = activity
        var reloaded = reloadedWorkspace
        reloaded.activity = activity
        return reloaded
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        var reloaded = reloadedWorkspace
        reloaded.activity = activity
        return reloaded
    }
}

private struct FailingInvoiceFinalizationWorkspacePersistence: WorkspacePersistence {
    enum Failure: Error {
        case applyFailed
    }

    let bootWorkspace: WorkspaceSnapshot

    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot {
        bootWorkspace
    }

    func isUsingNormalizedPersistence() -> Bool {
        true
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {}

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot {
        throw Failure.applyFailed
    }

    func persistWorkspace() throws {}

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        bootWorkspace
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        bootWorkspace
    }
}

private final class SuccessfulInvoiceFinalizationWithFailingExtraSavePersistence: WorkspacePersistence {
    enum Failure: Error {
        case extraSaveShouldNotRun
        case missingCommittedRecord
    }

    private(set) var persistCallCount = 0
    let bootWorkspace: WorkspaceSnapshot

    init(bootWorkspace: WorkspaceSnapshot) {
        self.bootWorkspace = bootWorkspace
    }

    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot {
        bootWorkspace
    }

    func isUsingNormalizedPersistence() -> Bool {
        true
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {}

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot {
        var reloaded = bootWorkspace
        guard let projectIndex = reloaded.projects.firstIndex(where: { $0.id == result.projectID }),
              let bucketIndex = reloaded.projects[projectIndex].buckets.firstIndex(where: { $0.id == result.bucketID })
        else {
            throw Failure.missingCommittedRecord
        }
        reloaded.projects[projectIndex].buckets[bucketIndex].status = .finalized
        reloaded.projects[projectIndex].invoices = [result.invoice]
        reloaded.activity = activity
        return reloaded
    }

    func persistWorkspace() throws {
        persistCallCount += 1
        throw Failure.extraSaveShouldNotRun
    }

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        bootWorkspace
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        bootWorkspace
    }
}

private final class ConflictingInvoiceFinalizationWorkspacePersistence: WorkspacePersistence {
    enum Failure: Error {
        case saveAndReloadShouldNotRun
    }

    private(set) var reloadCallCount = 0
    let bootWorkspace: WorkspaceSnapshot

    init(bootWorkspace: WorkspaceSnapshot) {
        self.bootWorkspace = bootWorkspace
    }

    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot {
        bootWorkspace
    }

    func isUsingNormalizedPersistence() -> Bool {
        true
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {}

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot {
        throw WorkspacePersistenceConflictError.invoiceFinalizationConflict
    }

    func persistWorkspace() throws {}

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        throw Failure.saveAndReloadShouldNotRun
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        reloadCallCount += 1
        var reloaded = bootWorkspace
        reloaded.activity = activity
        return reloaded
    }
}

private struct RejectPaidInvoicingWorkflow: WorkspaceInvoicing {
    private let defaultWorkflow = WorkspaceInvoicingWorkflow()

    func ensureInvoiceStatusTransition(from sourceStatus: InvoiceStatus, to targetStatus: InvoiceStatus) throws {
        if targetStatus == .paid {
            throw WorkspaceInvoicingWorkflowError.invalidInvoiceStatusTransition(
                from: sourceStatus,
                to: targetStatus
            )
        }
        try defaultWorkflow.ensureInvoiceStatusTransition(from: sourceStatus, to: targetStatus)
    }

    func finalizeInvoice(
        workspace: WorkspaceSnapshot,
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: InvoiceFinalizationDraft
    ) throws -> InvoiceFinalizationResult {
        try defaultWorkflow.finalizeInvoice(
            workspace: workspace,
            projectID: projectID,
            bucketID: bucketID,
            draft: draft
        )
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

        for lockedStatus in [BucketStatus.open, .ready, .finalized] {
            #expect(throws: WorkspaceStoreError.bucketLocked(lockedStatus)) {
                try policy.ensureBucketCanBeRemoved(status: lockedStatus)
            }
        }

        try policy.ensureBucketCanBeRemoved(status: .archived)
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

    @Test func invoicingWorkflowCanOverrideInvoiceTransitions() throws {
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

        let store = WorkspaceStore(
            seed: workspace,
            invoicingWorkflow: RejectPaidInvoicingWorkflow()
        )
        #expect(throws: WorkspaceStoreError.invalidInvoiceStatusTransition(from: .finalized, to: .paid)) {
            try store.markInvoicePaid(invoiceID: invoiceID)
        }
    }

    @Test func mutationPolicyCanOverrideArchivedBucketRemovalRuleAcrossStorePaths() throws {
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
        let inMemoryStore = WorkspaceStore(seed: workspace, mutationPolicy: RejectArchivedBucketRemovalPolicy())

        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try inMemoryStore.removeBucket(projectID: projectID, bucketID: bucketID)
        }
        #expect(inMemoryStore.workspace.projects.first?.buckets.map(\.id) == [bucketID])

        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
        let persistentStore = WorkspaceStore(
            seed: workspace,
            modelContext: modelContext,
            mutationPolicy: RejectArchivedBucketRemovalPolicy()
        )

        #expect(persistentStore.isUsingNormalizedWorkspacePersistence())
        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try persistentStore.removeBucket(projectID: projectID, bucketID: bucketID)
        }
        #expect(persistentStore.workspace.projects.first?.buckets.map(\.id) == [bucketID])
    }

    @Test func normalizedInvoiceFinalizationMapsUnexpectedPersistenceFailuresToPersistenceFailed() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009997")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009997")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009997")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 2)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 16)
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Pipeline Client",
                    email: "billing@pipeline.example",
                    billingAddress: "9 Pipeline Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Pipeline Project",
                    clientName: "Pipeline Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Bucket",
                            status: .ready,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: UUID(uuidString: "50000000-0000-0000-0000-000000009997")!,
                                    date: issueDate,
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Architecture validation",
                                    isBillable: true,
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )
        let store = WorkspaceStore(
            seed: workspace,
            workspacePersistence: FailingInvoiceFinalizationWorkspacePersistence(bootWorkspace: workspace)
        )

        #expect(store.isUsingNormalizedWorkspacePersistence())
        #expect(throws: WorkspaceStoreError.persistenceFailed) {
            try store.finalizeInvoice(
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Pipeline Client",
                    recipientEmail: "billing@pipeline.example",
                    recipientBillingAddress: "9 Pipeline Way",
                    invoiceNumber: "NCS-2026-997",
                    template: .kleinunternehmerClassic,
                    issueDate: issueDate,
                    dueDate: dueDate,
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                ),
                occurredAt: issueDate
            )
        }

        let project = try #require(store.workspace.projects.first(where: { $0.id == projectID }))
        #expect(project.invoices.isEmpty)
        #expect(project.buckets.first(where: { $0.id == bucketID })?.status == .ready)
    }

    @Test func normalizedInvoiceFinalizationDoesNotFailAfterSuccessfulCommitWithExtraSave() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009993")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009993")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009993")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 9)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 23)
        let draft = InvoiceFinalizationDraft(
            recipientName: "Committed Client",
            recipientEmail: "billing@committed.example",
            recipientBillingAddress: "5 Committed Way",
            invoiceNumber: "NCS-2026-993",
            template: .kleinunternehmerClassic,
            issueDate: issueDate,
            dueDate: dueDate,
            servicePeriod: "May 2026",
            currencyCode: "EUR",
            taxNote: ""
        )
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Committed Client",
                    email: "billing@committed.example",
                    billingAddress: "5 Committed Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Committed Project",
                    clientName: "Committed Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Committed",
                            status: .ready,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: UUID(uuidString: "50000000-0000-0000-0000-000000009993")!,
                                    date: issueDate,
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Commit validation",
                                    isBillable: true,
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )
        let persistence = SuccessfulInvoiceFinalizationWithFailingExtraSavePersistence(
            bootWorkspace: workspace
        )
        let store = WorkspaceStore(
            seed: workspace,
            workspacePersistence: persistence
        )

        let invoice = try store.finalizeInvoice(
            projectID: projectID,
            bucketID: bucketID,
            draft: draft,
            occurredAt: issueDate
        )

        #expect(invoice.number == "NCS-2026-993")
        #expect(persistence.persistCallCount == 0)
        #expect(store.workspace.projects.first?.buckets.first?.status == .finalized)
        #expect(store.workspace.activity.map(\.message) == ["NCS-2026-993 finalized"])
    }

    @Test func repeatedInvoiceFinalizationForSameFinalizedBucketReturnsExistingInvoice() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009992")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009992")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009992")!
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000009992")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 10)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 24)
        let invoice = WorkspaceInvoice(
            id: invoiceID,
            number: "NCS-2026-992",
            clientName: "Replay Client",
            projectID: projectID,
            projectName: "Replay Project",
            bucketID: bucketID,
            bucketName: "Replay Bucket",
            issueDate: issueDate,
            dueDate: dueDate,
            status: .finalized,
            totalMinorUnits: 10_000
        )
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Replay Client",
                    email: "billing@replay.example",
                    billingAddress: "4 Replay Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Replay Project",
                    clientName: "Replay Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Replay Bucket",
                            status: .finalized,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: [invoice]
                ),
            ],
            activity: []
        )
        let store = WorkspaceStore(seed: workspace)

        let replayedInvoice = try store.finalizeInvoice(
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Replay Client",
                recipientEmail: "billing@replay.example",
                recipientBillingAddress: "4 Replay Way",
                invoiceNumber: " NCS-2026-992 ",
                template: .kleinunternehmerClassic,
                issueDate: issueDate,
                dueDate: dueDate,
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: ""
            ),
            occurredAt: issueDate
        )

        #expect(replayedInvoice.id == invoiceID)
        #expect(store.workspace.projects.first?.invoices.count == 1)
        #expect(store.workspace.activity.isEmpty)
    }

    @Test func normalizedInvoiceFinalizationConflictReloadsWithoutSavingFirst() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009996")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009996")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009996")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 2)
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Conflict Client",
                    email: "billing@conflict.example",
                    billingAddress: "8 Conflict Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Conflict Project",
                    clientName: "Conflict Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Conflict",
                            status: .ready,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: UUID(uuidString: "50000000-0000-0000-0000-000000009996")!,
                                    date: issueDate,
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Conflict validation",
                                    isBillable: true,
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )
        let persistence = ConflictingInvoiceFinalizationWorkspacePersistence(bootWorkspace: workspace)
        let store = WorkspaceStore(
            seed: workspace,
            workspacePersistence: persistence
        )

        #expect(throws: WorkspaceStoreError.persistenceConflict) {
            try store.finalizeInvoice(
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Conflict Client",
                    recipientEmail: "billing@conflict.example",
                    recipientBillingAddress: "8 Conflict Way",
                    invoiceNumber: "NCS-2026-996",
                    template: .kleinunternehmerClassic,
                    issueDate: issueDate,
                    dueDate: Date.pikaDate(year: 2026, month: 5, day: 16),
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                ),
                occurredAt: issueDate
            )
        }
        #expect(persistence.reloadCallCount == 1)
        #expect(store.workspace.projects.first?.invoices.isEmpty == true)
    }

    @Test func defaultPersistenceRollsBackFinalizationWhenSaveFailsAfterMutation() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009995")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009995")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009995")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 7)
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Rollback Client",
                    email: "billing@rollback.example",
                    billingAddress: "7 Rollback Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Rollback Project",
                    clientName: "Rollback Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Rollback",
                            status: .ready,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: UUID(uuidString: "50000000-0000-0000-0000-000000009995")!,
                                    date: issueDate,
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Rollback validation",
                                    isBillable: true,
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )
        let result = try WorkspaceInvoicingWorkflow().finalizeInvoice(
            workspace: workspace,
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Rollback Client",
                recipientEmail: "billing@rollback.example",
                recipientBillingAddress: "7 Rollback Way",
                invoiceNumber: "NCS-2026-995",
                template: .kleinunternehmerClassic,
                issueDate: issueDate,
                dueDate: Date.pikaDate(year: 2026, month: 5, day: 21),
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: ""
            )
        )
        let adapter = SaveFailingPersistenceAdapter()
        let persistence = DefaultWorkspacePersistence(
            modelContext: modelContext,
            usesNormalizedPersistence: true,
            projectionLoadingAdapter: EmptyProjectionLoader(),
            persistenceAdapter: adapter
        )

        #expect(throws: SaveFailingPersistenceAdapter.Failure.saveFailed) {
            try persistence.applyInvoiceFinalizationResult(result, preservingActivity: [])
        }
        #expect(adapter.applyCallCount == 1)
        #expect(adapter.rollbackCallCount == 1)
    }

    @Test func defaultPersistenceDoesNotRollbackFinalizationWhenPostSaveReloadFails() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009994")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009994")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009994")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 8)
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Reload Client",
                    email: "billing@reload.example",
                    billingAddress: "6 Reload Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Reload Project",
                    clientName: "Reload Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Reload",
                            status: .ready,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: UUID(uuidString: "50000000-0000-0000-0000-000000009994")!,
                                    date: issueDate,
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Reload validation",
                                    isBillable: true,
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )
        let result = try WorkspaceInvoicingWorkflow().finalizeInvoice(
            workspace: workspace,
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Reload Client",
                recipientEmail: "billing@reload.example",
                recipientBillingAddress: "6 Reload Way",
                invoiceNumber: "NCS-2026-994",
                template: .kleinunternehmerClassic,
                issueDate: issueDate,
                dueDate: Date.pikaDate(year: 2026, month: 5, day: 22),
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: ""
            )
        )
        let adapter = SaveSucceedingPersistenceAdapter()
        let persistence = DefaultWorkspacePersistence(
            modelContext: modelContext,
            usesNormalizedPersistence: true,
            projectionLoadingAdapter: EmptyProjectionLoader(),
            persistenceAdapter: adapter
        )

        #expect(throws: WorkspaceStoreError.persistenceFailed) {
            try persistence.applyInvoiceFinalizationResult(result, preservingActivity: [])
        }
        #expect(adapter.applyCallCount == 1)
        #expect(adapter.saveCallCount == 1)
        #expect(adapter.rollbackCallCount == 0)
    }
}
