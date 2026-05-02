import Foundation
import SwiftData
import Testing
@testable import pika

@MainActor
struct WorkspaceArchiveImportValidationTests {
    @Test func confirmedImportReplacesWorkspaceAndPreservesSnapshots() throws {
        let initialWorkspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "Legacy Client",
                    email: "legacy@example.com",
                    billingAddress: "1 Legacy Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [],
            activity: [
                WorkspaceActivity(
                    message: "Legacy activity",
                    detail: "Should be excluded from archive import",
                    occurredAt: Date.pikaDate(year: 2026, month: 5, day: 1)
                ),
            ]
        )
        let persistence = CapturingArchiveImportWorkspacePersistence(bootWorkspace: initialWorkspace)
        let store = WorkspaceStore(seed: initialWorkspace, workspacePersistence: persistence)
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeReplacementEnvelope()
        )

        let summary = try store.importWorkspaceArchive(archiveData)

        #expect(summary == WorkspaceArchiveImportSummary(
            clientCount: 1,
            projectCount: 1,
            bucketCount: 1,
            timeEntryCount: 2,
            fixedCostCount: 1,
            invoiceCount: 1
        ))
        #expect(persistence.replaceCallCount == 1)
        #expect(store.workspace.clients.map(\.name) == ["Snapshot Client"])
        #expect(store.workspace.clients.map(\.name).contains("Legacy Client") == false)
        #expect(store.workspace.activity.isEmpty)

        let project = try #require(store.workspace.projects.first)
        let bucket = try #require(project.buckets.first)
        #expect(bucket.effectiveBillableMinutes == 60)
        #expect(bucket.effectiveNonBillableMinutes == 30)
        #expect(bucket.effectiveFixedCostMinorUnits == 32_000)
        #expect(bucket.effectiveTotalMinorUnits == 42_000)
        #expect(bucket.fixedCostEntries.map(\.amountMinorUnits) == [32_000])
        #expect(bucket.timeEntries.filter(\.isBillable).count == 1)
        #expect(bucket.timeEntries.filter { !$0.isBillable }.count == 1)

        let invoice = try #require(project.invoices.first)
        #expect(invoice.status == .sent)
        #expect(invoice.number == "EHX-2026-042")
        #expect(invoice.currencyCode == "EUR")
        #expect(invoice.totalMinorUnits == 42_000)
        #expect(invoice.note == "Archive invoice note")
        #expect(invoice.businessSnapshot?.businessName == "North Coast Studio")
        #expect(invoice.businessSnapshot?.personName == "Avery North")
        #expect(invoice.clientSnapshot?.name == "Snapshot Client")
        #expect(invoice.clientSnapshot?.email == "billing@snapshot.example")
        #expect(invoice.projectName == "Snapshot Project")
        #expect(invoice.bucketName == "Ready Snapshot")
        #expect(invoice.lineItems.map(\.description) == [
            "Billable work",
            "Design package",
        ])
        #expect(invoice.lineItems.map(\.quantityLabel) == [
            "1h",
            "1 item",
        ])
        #expect(invoice.lineItems.map(\.amountMinorUnits) == [
            10_000,
            32_000,
        ])
    }

    @Test func replacementFailureLeavesCurrentWorkspaceUntouched() throws {
        let initialWorkspace = WorkspaceFixtures.demoWorkspace
        let persistence = CapturingArchiveImportWorkspacePersistence(
            bootWorkspace: initialWorkspace,
            replaceFailure: CapturingArchiveImportWorkspacePersistence.Failure.replaceFailed
        )
        let store = WorkspaceStore(seed: initialWorkspace, workspacePersistence: persistence)
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeReplacementEnvelope()
        )

        #expect(throws: WorkspaceStoreError.persistenceFailed) {
            _ = try store.importWorkspaceArchive(archiveData)
        }
        #expect(persistence.replaceCallCount == 1)
        #expect(store.workspace == initialWorkspace)
    }

    @Test func confirmedImportReplacesNormalizedPersistentRecordsRatherThanMerging() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let baselineWorkspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: UUID(uuidString: "19999999-0000-0000-0000-000000000001")!,
                    name: "Legacy Persistent Client",
                    email: "legacy-persistent@example.com",
                    billingAddress: "1 Legacy Persistent Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [],
            activity: []
        )
        let store = WorkspaceStore(seed: baselineWorkspace, modelContext: modelContext)
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeReplacementEnvelope()
        )

        _ = try store.importWorkspaceArchive(archiveData)

        let clientRecords = try modelContext.fetch(FetchDescriptor<ClientRecord>())
        let projectRecords = try modelContext.fetch(FetchDescriptor<ProjectRecord>())
        let bucketRecords = try modelContext.fetch(FetchDescriptor<BucketRecord>())
        let timeEntryRecords = try modelContext.fetch(FetchDescriptor<TimeEntryRecord>())
        let fixedCostRecords = try modelContext.fetch(FetchDescriptor<FixedCostRecord>())
        let invoiceRecords = try modelContext.fetch(FetchDescriptor<InvoiceRecord>())
        let lineItemRecords = try modelContext.fetch(FetchDescriptor<InvoiceLineItemRecord>())
            .sorted(by: { $0.sortOrder < $1.sortOrder })

        #expect(clientRecords.count == 1)
        #expect(clientRecords.map(\.name) == ["Snapshot Client"])
        #expect(clientRecords.map(\.name).contains("Legacy Persistent Client") == false)
        #expect(projectRecords.count == 1)
        #expect(bucketRecords.count == 1)
        #expect(timeEntryRecords.count == 2)
        #expect(timeEntryRecords.filter(\.isBillable).count == 1)
        #expect(timeEntryRecords.filter { !$0.isBillable }.count == 1)
        #expect(fixedCostRecords.count == 1)
        #expect(fixedCostRecords[0].quantity == 1)
        #expect(fixedCostRecords[0].unitPriceMinorUnits == 32_000)
        #expect(invoiceRecords.count == 1)
        #expect(invoiceRecords[0].note == "Archive invoice note")
        #expect(lineItemRecords.map(\.descriptionText) == ["Billable work", "Design package"])
        #expect(lineItemRecords.map(\.amountMinorUnits) == [10_000, 32_000])
    }

    @Test func duplicateNormalizedInvoiceNumbersFailWithoutMutatingWorkspace() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let originalWorkspace = store.workspace
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeDuplicateInvoiceNumberEnvelope()
        )

        #expect(throws: WorkspaceArchiveImportError.duplicateInvoiceNumber("ehx-2026-042")) {
            _ = try store.validateImportedWorkspaceArchive(archiveData)
        }
        #expect(store.workspace == originalWorkspace)
    }

    @Test func validArchiveReturnsCompactImportSummaryCounts() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeValidEnvelope()
        )

        let summary = try store.validateImportedWorkspaceArchive(archiveData)
        #expect(summary == WorkspaceArchiveImportSummary(
            clientCount: 1,
            projectCount: 1,
            bucketCount: 1,
            timeEntryCount: 1,
            fixedCostCount: 1,
            invoiceCount: 1
        ))
    }

    @Test func invoiceTotalMismatchFailsWithoutMutatingWorkspace() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let originalWorkspace = store.workspace
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeInvoiceTotalMismatchEnvelope()
        )

        #expect(throws: WorkspaceArchiveImportError.invoiceTotalMismatch(
            invoiceID: UUID(uuidString: "70000000-0000-0000-0000-000000000001")!,
            expected: 42_000,
            actual: 41_000
        )) {
            _ = try store.validateImportedWorkspaceArchive(archiveData)
        }
        #expect(store.workspace == originalWorkspace)
    }

    @Test func missingRelationshipFailsWithoutMutatingWorkspace() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let originalWorkspace = store.workspace
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeMissingBucketRelationshipEnvelope()
        )

        #expect(throws: WorkspaceArchiveImportError.missingRelationship(
            entity: "timeEntry",
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
            relationship: "bucketID",
            targetID: UUID(uuidString: "49999999-0000-0000-0000-000000000001")!
        )) {
            _ = try store.validateImportedWorkspaceArchive(archiveData)
        }
        #expect(store.workspace == originalWorkspace)
    }

    @Test func lifecycleWeirdnessDoesNotBlockStructurallyValidImport() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeLifecycleWeirdButValidEnvelope()
        )

        let summary = try store.validateImportedWorkspaceArchive(archiveData)
        #expect(summary.invoiceCount == 1)
        #expect(summary.bucketCount == 1)
    }

    @Test func lowercaseCurrencyCodeFailsWithoutMutatingWorkspace() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let originalWorkspace = store.workspace
        let archiveData = try WorkspaceArchiveCodec.encode(
            WorkspaceArchiveImportFixture.makeLowercaseCurrencyEnvelope()
        )

        #expect(throws: WorkspaceArchiveImportError.invalidCurrencyCode(
            field: "businessProfile.currencyCode",
            value: "eur"
        )) {
            _ = try store.validateImportedWorkspaceArchive(archiveData)
        }
        #expect(store.workspace == originalWorkspace)
    }
}

private enum WorkspaceArchiveImportFixture {
    static func makeReplacementEnvelope() -> WorkspaceArchiveEnvelope {
        var workspace = makeValidWorkspace()
        workspace.timeEntries.append(WorkspaceArchiveV1Workspace.TimeEntry(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
            bucketID: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            date: "2026-05-01",
            startMinuteOfDay: 600,
            endMinuteOfDay: 630,
            durationMinutes: 30,
            description: "Internal review",
            isBillable: false,
            hourlyRateMinorUnits: 10_000
        ))
        workspace.invoices[0].status = .sent
        workspace.invoices[0].note = "Archive invoice note"
        workspace.invoiceLineItems = [
            WorkspaceArchiveV1Workspace.InvoiceLineItem(
                id: UUID(uuidString: "80000000-0000-0000-0000-000000000011")!,
                invoiceID: UUID(uuidString: "70000000-0000-0000-0000-000000000001")!,
                sortOrder: 0,
                description: "Billable work",
                quantityLabel: "1h",
                amountMinorUnits: 10_000
            ),
            WorkspaceArchiveV1Workspace.InvoiceLineItem(
                id: UUID(uuidString: "80000000-0000-0000-0000-000000000012")!,
                invoiceID: UUID(uuidString: "70000000-0000-0000-0000-000000000001")!,
                sortOrder: 1,
                description: "Design package",
                quantityLabel: "1 item",
                amountMinorUnits: 32_000
            ),
        ]
        return makeEnvelope(workspace: workspace)
    }

    static func makeValidEnvelope() -> WorkspaceArchiveEnvelope {
        makeEnvelope(workspace: makeValidWorkspace())
    }

    static func makeDuplicateInvoiceNumberEnvelope() -> WorkspaceArchiveEnvelope {
        var workspace = makeValidWorkspace()
        let secondInvoiceID = UUID(uuidString: "70000000-0000-0000-0000-000000000002")!
        let lineID = UUID(uuidString: "80000000-0000-0000-0000-000000000002")!
        let first = workspace.invoices[0]

        workspace.invoices.append(WorkspaceArchiveV1Workspace.Invoice(
            id: secondInvoiceID,
            projectID: first.projectID,
            bucketID: first.bucketID,
            number: "  ehx-2026-042  ",
            businessSnapshot: first.businessSnapshot,
            clientSnapshot: first.clientSnapshot,
            template: first.template,
            issueDate: first.issueDate,
            dueDate: first.dueDate,
            servicePeriod: first.servicePeriod,
            status: .sent,
            totalMinorUnits: 12_000,
            currencyCode: first.currencyCode,
            note: first.note
        ))
        workspace.invoiceLineItems.append(WorkspaceArchiveV1Workspace.InvoiceLineItem(
            id: lineID,
            invoiceID: secondInvoiceID,
            sortOrder: 0,
            description: "Line B",
            quantityLabel: "1h",
            amountMinorUnits: 12_000
        ))

        return makeEnvelope(workspace: workspace)
    }

    static func makeInvoiceTotalMismatchEnvelope() -> WorkspaceArchiveEnvelope {
        var workspace = makeValidWorkspace()
        workspace.invoiceLineItems[0].amountMinorUnits = 41_000
        return makeEnvelope(workspace: workspace)
    }

    static func makeMissingBucketRelationshipEnvelope() -> WorkspaceArchiveEnvelope {
        var workspace = makeValidWorkspace()
        workspace.timeEntries[0].bucketID = UUID(uuidString: "49999999-0000-0000-0000-000000000001")!
        return makeEnvelope(workspace: workspace)
    }

    static func makeLifecycleWeirdButValidEnvelope() -> WorkspaceArchiveEnvelope {
        var workspace = makeValidWorkspace()
        workspace.buckets[0].status = .archived
        workspace.projects[0].isArchived = false
        workspace.invoices[0].status = .paid
        return makeEnvelope(workspace: workspace)
    }

    static func makeLowercaseCurrencyEnvelope() -> WorkspaceArchiveEnvelope {
        var workspace = makeValidWorkspace()
        workspace.businessProfile.currencyCode = "eur"
        return makeEnvelope(workspace: workspace)
    }

    private static func makeEnvelope(workspace: WorkspaceArchiveV1Workspace) -> WorkspaceArchiveEnvelope {
        WorkspaceArchiveEnvelope.v1(
            exportedAt: Date.pikaDate(year: 2026, month: 5, day: 2),
            generator: WorkspaceArchiveGenerator(app: "pika-tests", version: "1.0.0", build: "test"),
            workspace: workspace
        )
    }

    private static func makeValidWorkspace() -> WorkspaceArchiveV1Workspace {
        let clientID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let projectID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let bucketID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let timeEntryID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
        let fixedCostID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
        let invoiceID = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
        let lineItemID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

        return WorkspaceArchiveV1Workspace(
            businessProfile: WorkspaceArchiveV1Workspace.BusinessProfile(
                businessName: "North Coast Studio",
                personName: "Avery North",
                email: "billing@northcoast.example",
                phone: "+49 555 0100",
                address: "1 Harbour Way",
                taxIdentifier: "DE123",
                economicIdentifier: "ECO123",
                invoicePrefix: "NCS",
                nextInvoiceNumber: 42,
                currencyCode: "EUR",
                paymentDetails: "IBAN DE00 1234",
                taxNote: "VAT exempt",
                defaultTermsDays: 14
            ),
            clients: [
                WorkspaceArchiveV1Workspace.Client(
                    id: clientID,
                    name: "Snapshot Client",
                    email: "billing@snapshot.example",
                    billingAddress: "1 Snapshot Way",
                    defaultTermsDays: 21,
                    isArchived: false
                ),
            ],
            projects: [
                WorkspaceArchiveV1Workspace.Project(
                    id: projectID,
                    clientID: clientID,
                    name: "Snapshot Project",
                    currencyCode: "EUR",
                    isArchived: false
                ),
            ],
            buckets: [
                WorkspaceArchiveV1Workspace.Bucket(
                    id: bucketID,
                    projectID: projectID,
                    name: "Ready Snapshot",
                    status: .ready,
                    defaultHourlyRateMinorUnits: 10_000
                ),
            ],
            timeEntries: [
                WorkspaceArchiveV1Workspace.TimeEntry(
                    id: timeEntryID,
                    bucketID: bucketID,
                    date: "2026-05-01",
                    startMinuteOfDay: 540,
                    endMinuteOfDay: 600,
                    durationMinutes: 60,
                    description: "Billable work",
                    isBillable: true,
                    hourlyRateMinorUnits: 10_000
                ),
            ],
            fixedCosts: [
                WorkspaceArchiveV1Workspace.FixedCost(
                    id: fixedCostID,
                    bucketID: bucketID,
                    date: "2026-05-01",
                    description: "Design package",
                    amountMinorUnits: 32_000
                ),
            ],
            invoices: [
                WorkspaceArchiveV1Workspace.Invoice(
                    id: invoiceID,
                    projectID: projectID,
                    bucketID: bucketID,
                    number: "EHX-2026-042",
                    businessSnapshot: WorkspaceArchiveV1Workspace.BusinessSnapshot(
                        businessName: "North Coast Studio",
                        personName: "Avery North",
                        email: "billing@northcoast.example",
                        phone: "+49 555 0100",
                        address: "1 Harbour Way",
                        taxIdentifier: "DE123",
                        economicIdentifier: "ECO123",
                        paymentDetails: "IBAN DE00 1234",
                        taxNote: "VAT exempt"
                    ),
                    clientSnapshot: WorkspaceArchiveV1Workspace.ClientSnapshot(
                        name: "Snapshot Client",
                        email: "billing@snapshot.example",
                        billingAddress: "1 Snapshot Way"
                    ),
                    template: InvoiceTemplate.kleinunternehmerClassic.rawValue,
                    issueDate: "2026-05-01",
                    dueDate: "2026-05-15",
                    servicePeriod: "May 2026",
                    status: .finalized,
                    totalMinorUnits: 42_000,
                    currencyCode: "EUR",
                    note: nil
                ),
            ],
            invoiceLineItems: [
                WorkspaceArchiveV1Workspace.InvoiceLineItem(
                    id: lineItemID,
                    invoiceID: invoiceID,
                    sortOrder: 0,
                    description: "Ready Snapshot",
                    quantityLabel: "1h",
                    amountMinorUnits: 42_000
                ),
            ]
        )
    }
}

private final class CapturingArchiveImportWorkspacePersistence: WorkspacePersistence {
    enum Failure: Error {
        case replaceFailed
    }

    private(set) var replaceCallCount = 0
    private let bootWorkspace: WorkspaceSnapshot
    private let replaceFailure: Error?

    init(bootWorkspace: WorkspaceSnapshot, replaceFailure: Error? = nil) {
        self.bootWorkspace = bootWorkspace
        self.replaceFailure = replaceFailure
    }

    func bootstrapWorkspace(seed: WorkspaceSnapshot, resetForSeedImport: Bool) -> WorkspaceSnapshot {
        bootWorkspace
    }

    func isUsingNormalizedPersistence() -> Bool {
        true
    }

    func replacePersistentWorkspaceWithSeedImport(_ snapshot: WorkspaceSnapshot) throws {
        replaceCallCount += 1
        if let replaceFailure {
            throw replaceFailure
        }
    }

    func applyInvoiceFinalizationResult(
        _ result: InvoiceFinalizationResult,
        preservingActivity activity: [WorkspaceActivity]
    ) throws -> WorkspaceSnapshot {
        bootWorkspace
    }

    func persistWorkspace() throws {}

    func saveAndReloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        bootWorkspace
    }

    func reloadNormalizedWorkspace(preservingActivity activity: [WorkspaceActivity]) throws -> WorkspaceSnapshot {
        bootWorkspace
    }
}
