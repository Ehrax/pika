import Foundation
import Testing
@testable import pika

@MainActor
struct WorkspaceArchiveImportValidationTests {
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
    static func makeValidEnvelope() -> WorkspaceArchiveEnvelope {
        let exportedAt = Date.pikaDate(year: 2026, month: 5, day: 2)
        let businessProfileID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let clientID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let projectID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let bucketID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let timeEntryID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
        let fixedCostID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
        let invoiceID = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
        let lineItemID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

        let invoiceSnapshot = WorkspaceArchiveBusinessProfileSnapshot(
            businessName: "North Coast Studio",
            personName: "Avery North",
            email: "billing@northcoast.example",
            phone: "+49 555 0100",
            address: "1 Harbour Way",
            taxIdentifier: "DE123",
            economicIdentifier: "ECO123",
            paymentDetails: "IBAN DE00 1234",
            taxNote: "VAT exempt"
        )

        return WorkspaceArchiveEnvelope(
            format: WorkspaceArchiveEnvelope.v1Format,
            version: WorkspaceArchiveEnvelope.v1Version,
            exportedAt: exportedAt,
            generator: WorkspaceArchiveGenerator(name: "pika-tests", version: "1.0.0"),
            workspace: WorkspaceArchiveWorkspace(
                businessProfile: WorkspaceArchiveBusinessProfile(
                    id: businessProfileID,
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
                    WorkspaceArchiveClient(
                        id: clientID,
                        name: "Snapshot Client",
                        email: "billing@snapshot.example",
                        billingAddress: "1 Snapshot Way",
                        defaultTermsDays: 21,
                        isArchived: false
                    ),
                ],
                projects: [
                    WorkspaceArchiveProject(
                        id: projectID,
                        clientID: clientID,
                        name: "Snapshot Project",
                        currencyCode: "EUR",
                        isArchived: false
                    ),
                ],
                buckets: [
                    WorkspaceArchiveBucket(
                        id: bucketID,
                        projectID: projectID,
                        name: "Ready Snapshot",
                        status: .ready,
                        defaultHourlyRateMinorUnits: 10_000
                    ),
                ],
                timeEntries: [
                    WorkspaceArchiveTimeEntry(
                        id: timeEntryID,
                        bucketID: bucketID,
                        workDate: Date.pikaDate(year: 2026, month: 5, day: 1),
                        startMinuteOfDay: 540,
                        endMinuteOfDay: 600,
                        durationMinutes: 60,
                        description: "Billable work",
                        isBillable: true,
                        hourlyRateMinorUnits: 10_000
                    ),
                ],
                fixedCosts: [
                    WorkspaceArchiveFixedCost(
                        id: fixedCostID,
                        bucketID: bucketID,
                        date: Date.pikaDate(year: 2026, month: 5, day: 1),
                        description: "Design package",
                        quantity: 1,
                        unitPriceMinorUnits: 32_000,
                        isBillable: true
                    ),
                ],
                invoices: [
                    WorkspaceArchiveInvoice(
                        id: invoiceID,
                        projectID: projectID,
                        bucketID: bucketID,
                        number: "EHX-2026-042",
                        template: .kleinunternehmerClassic,
                        issueDate: Date.pikaDate(year: 2026, month: 5, day: 1),
                        dueDate: Date.pikaDate(year: 2026, month: 5, day: 15),
                        servicePeriod: "May 2026",
                        status: .finalized,
                        totalMinorUnits: 42_000,
                        currencyCode: "EUR",
                        note: "",
                        businessProfileSnapshot: invoiceSnapshot,
                        clientSnapshot: WorkspaceArchiveClientSnapshot(
                            name: "Snapshot Client",
                            email: "billing@snapshot.example",
                            billingAddress: "1 Snapshot Way"
                        ),
                        projectSnapshot: WorkspaceArchiveProjectSnapshot(name: "Snapshot Project"),
                        bucketSnapshot: WorkspaceArchiveBucketSnapshot(name: "Ready Snapshot")
                    ),
                ],
                invoiceLineItems: [
                    WorkspaceArchiveInvoiceLineItem(
                        id: lineItemID,
                        invoiceID: invoiceID,
                        sortOrder: 0,
                        description: "Ready Snapshot",
                        quantityLabel: "1h",
                        amountMinorUnits: 42_000
                    ),
                ]
            )
        )
    }

    static func makeDuplicateInvoiceNumberEnvelope() -> WorkspaceArchiveEnvelope {
        var envelope = makeValidEnvelope()
        let secondInvoiceID = UUID(uuidString: "70000000-0000-0000-0000-000000000002")!
        let lineID = UUID(uuidString: "80000000-0000-0000-0000-000000000002")!
        let first = envelope.workspace.invoices[0]
        let duplicateInvoice = WorkspaceArchiveInvoice(
            id: secondInvoiceID,
            projectID: first.projectID,
            bucketID: first.bucketID,
            number: "  ehx-2026-042  ",
            template: first.template,
            issueDate: first.issueDate,
            dueDate: first.dueDate,
            servicePeriod: first.servicePeriod,
            status: .sent,
            totalMinorUnits: 12_000,
            currencyCode: first.currencyCode,
            note: first.note,
            businessProfileSnapshot: first.businessProfileSnapshot,
            clientSnapshot: first.clientSnapshot,
            projectSnapshot: first.projectSnapshot,
            bucketSnapshot: first.bucketSnapshot
        )

        envelope.workspace.invoices.append(duplicateInvoice)
        envelope.workspace.invoiceLineItems.append(
            WorkspaceArchiveInvoiceLineItem(
                id: lineID,
                invoiceID: secondInvoiceID,
                sortOrder: 0,
                description: "Line B",
                quantityLabel: "1h",
                amountMinorUnits: 12_000
            )
        )
        return envelope
    }

    static func makeInvoiceTotalMismatchEnvelope() -> WorkspaceArchiveEnvelope {
        var envelope = makeValidEnvelope()
        envelope.workspace.invoiceLineItems[0].amountMinorUnits = 41_000
        return envelope
    }

    static func makeMissingBucketRelationshipEnvelope() -> WorkspaceArchiveEnvelope {
        var envelope = makeValidEnvelope()
        envelope.workspace.timeEntries[0].bucketID = UUID(uuidString: "49999999-0000-0000-0000-000000000001")!
        return envelope
    }

    static func makeLifecycleWeirdButValidEnvelope() -> WorkspaceArchiveEnvelope {
        var envelope = makeValidEnvelope()
        envelope.workspace.buckets[0].status = .archived
        envelope.workspace.projects[0].isArchived = false
        envelope.workspace.invoices[0].status = .paid
        return envelope
    }

    static func makeLowercaseCurrencyEnvelope() -> WorkspaceArchiveEnvelope {
        var envelope = makeValidEnvelope()
        envelope.workspace.businessProfile.currencyCode = "eur"
        return envelope
    }
}
