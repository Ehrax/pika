import Foundation
import SwiftData
import Testing
@testable import billbi

struct WorkspaceStoreMutationTests {
    @Test func inMemoryWorkspaceStoreMarksOpenInvoiceableBucketReadyAndRecordsActivity() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000501")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000501")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Store workflow",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Open invoiceable",
                            status: .open,
                            totalMinorUnits: 75_000,
                            billableMinutes: 360,
                            fixedCostMinorUnits: 15_000,
                            nonBillableMinutes: 45
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let occurredAt = Date(timeIntervalSince1970: 1_775_664_000)

        try store.markBucketReady(projectID: projectID, bucketID: bucketID, occurredAt: occurredAt)

        let project = try #require(store.workspace.projects.first)
        let bucket = try #require(project.buckets.first)
        #expect(bucket.status == .ready)
        let activity = try #require(store.workspace.activity.first)
        #expect(activity.message == "Open invoiceable marked ready")
        #expect(activity.detail == "Store workflow")
        #expect(activity.occurredAt == occurredAt)
    }

    @Test func inMemoryWorkspaceStoreFinalizesReadyBucketWithSnapshotAndNextNumber() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000601")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000601")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000601")!
        var businessProfile = WorkspaceFixtures.demoWorkspace.businessProfile
        businessProfile.nextInvoiceNumber = 9
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Snapshot Client",
                    email: "billing@snapshot.example",
                    billingAddress: "1 Snapshot Way",
                    defaultTermsDays: 21
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Snapshot Project",
                    clientName: "Snapshot Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Snapshot",
                            status: .ready,
                            totalMinorUnits: 132_000,
                            billableMinutes: 600,
                            fixedCostMinorUnits: 32_000,
                            nonBillableMinutes: 90
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let issueDate = Date(timeIntervalSince1970: 1_777_392_000)
        let dueDate = Date(timeIntervalSince1970: 1_779_984_000)

        let invoice = try store.finalizeInvoice(
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Snapshot Client",
                recipientEmail: "billing@snapshot.example",
                recipientBillingAddress: "1 Snapshot Way",
                invoiceNumber: "EHX-2026-009",
                template: .kleinunternehmerClassic,
                issueDate: issueDate,
                dueDate: dueDate,
                servicePeriod: "Apr 2026",
                currencyCode: "EUR",
                taxNote: "Thank you."
            ),
            occurredAt: issueDate
        )

        store.workspace.businessProfile.businessName = "Changed Business"
        store.workspace.clients[0].billingAddress = "Changed Address"
        store.workspace.projects[0].name = "Changed Project"
        store.workspace.projects[0].buckets[0].name = "Changed Bucket"

        let updatedProject = try #require(store.workspace.projects.first)
        let updatedBucket = try #require(updatedProject.buckets.first)
        let storedInvoice = try #require(updatedProject.invoices.first)
        #expect(invoice.number == "EHX-2026-009")
        #expect(updatedBucket.status == .finalized)
        #expect(store.workspace.businessProfile.nextInvoiceNumber == 10)
        #expect(storedInvoice.businessSnapshot?.businessName == businessProfile.businessName)
        #expect(storedInvoice.clientSnapshot?.billingAddress == "1 Snapshot Way")
        #expect(storedInvoice.projectName == "Snapshot Project")
        #expect(storedInvoice.bucketName == "Ready Snapshot")
        #expect(storedInvoice.template == .kleinunternehmerClassic)
        #expect(storedInvoice.servicePeriod == "Apr 2026")
        #expect(storedInvoice.currencyCode == "EUR")
        #expect(storedInvoice.note == "Thank you.")
        #expect(storedInvoice.lineItems.map(\.description) == [
            "Ready Snapshot",
            "Fixed Charges",
        ])
        #expect(storedInvoice.lineItems.map(\.quantityLabel) == [
            "10h",
            "1 item",
        ])
        #expect(store.workspace.activity.map(\.message) == [
            "EHX-2026-009 finalized",
        ])
    }

    @Test func invoiceFinalizationOnlyAllowsReviewSpecificFieldsToBeEdited() {
        #expect(InvoiceFinalizationField.editableFields == [
            .template,
            .issueDate,
            .dueDate,
        ])

        #expect(InvoiceFinalizationField.readOnlyFields == [
            .recipientName,
            .recipientEmail,
            .recipientBillingAddress,
            .invoiceNumber,
            .servicePeriod,
            .currencyCode,
            .taxNote,
        ])
    }

    @Test func inMemoryWorkspaceStoreAppliesInvoiceStatusTransitionsAndRejectsInvalidOnes() throws {
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000701")!
        var workspace = WorkspaceFixtures.demoWorkspace
        workspace.projects = [
            WorkspaceProject(
                id: UUID(uuidString: "20000000-0000-0000-0000-000000000701")!,
                name: "Status Project",
                clientName: "Happ.ines",
                currencyCode: "EUR",
                isArchived: false,
                buckets: [],
                invoices: [
                    WorkspaceInvoice(
                        id: invoiceID,
                        number: "EHX-2026-701",
                        clientName: "Happ.ines",
                        issueDate: Date(timeIntervalSince1970: 0),
                        dueDate: Date(timeIntervalSince1970: 86_400),
                        status: .finalized,
                        totalMinorUnits: 42_000
                    ),
                ]
            ),
        ]
        workspace.activity = []
        let store = WorkspaceStore(seed: workspace)
        let occurredAt = Date(timeIntervalSince1970: 172_800)

        try store.markInvoiceSent(invoiceID: invoiceID, occurredAt: occurredAt)
        #expect(store.workspace.projects[0].invoices[0].status == .sent)

        try store.markInvoicePaid(invoiceID: invoiceID, occurredAt: occurredAt.addingTimeInterval(60))
        #expect(store.workspace.projects[0].invoices[0].status == .paid)
        #expect(throws: WorkspaceStoreError.invalidInvoiceStatusTransition(from: .paid, to: .sent)) {
            try store.markInvoiceSent(invoiceID: invoiceID, occurredAt: occurredAt)
        }

        let finalizedInvoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000702")!
        store.workspace.projects[0].invoices.append(WorkspaceInvoice(
            id: finalizedInvoiceID,
            number: "EHX-2026-702",
            clientName: "Happ.ines",
            issueDate: Date(timeIntervalSince1970: 0),
            dueDate: Date(timeIntervalSince1970: 86_400),
            status: .finalized,
            totalMinorUnits: 24_000
        ))

        try store.markInvoicePaid(invoiceID: finalizedInvoiceID, occurredAt: occurredAt)
        #expect(store.workspace.projects[0].invoices[1].status == .paid)
        #expect(store.workspace.activity.map(\.message) == [
            "EHX-2026-701 marked sent",
            "EHX-2026-701 marked paid",
            "EHX-2026-702 marked paid",
        ])
    }

    @Test func inMemoryWorkspaceStoreCreatesProjectWithStarterBucket() throws {
        let clientID = try #require(WorkspaceFixtures.demoWorkspace.clients.first?.id)
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [],
            activity: []
        ))
        let date = Date.billbiDate(year: 2026, month: 4, day: 27)

        let project = try store.createProject(
            WorkspaceProjectDraft(
                name: "Client portal",
                clientID: clientID,
                currencyCode: "EUR",
                firstBucketName: "MVP",
                hourlyRateMinorUnits: 12_000
            ),
            occurredAt: date
        )

        #expect(project.name == "Client portal")
        #expect(project.buckets.map(\.name) == ["MVP"])
        #expect(project.buckets.first?.hourlyRateMinorUnits == 12_000)
        #expect(store.workspace.projects.map(\.id) == [project.id])
        #expect(store.workspace.activity.map(\.message) == ["Client portal project created"])
    }

    @Test func inMemoryWorkspaceStoreCreatesModeSpecificBucketsAndLocksBillingModeOnUpdate() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000004801")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Billing modes",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        ))

        let fixedBucket = try store.createBucket(
            projectID: projectID,
            WorkspaceBucketDraft(
                name: "  Launch package  ",
                billingMode: .fixed,
                hourlyRateMinorUnits: 0,
                fixedAmountMinorUnits: 240_000
            )
        )
        let retainerBucket = try store.createBucket(
            projectID: projectID,
            WorkspaceBucketDraft(
                name: "Support retainer",
                billingMode: .retainer,
                hourlyRateMinorUnits: 0,
                retainerAmountMinorUnits: 160_000,
                retainerPeriodLabel: "Monthly",
                retainerIncludedMinutes: 600,
                retainerOverageRateMinorUnits: 12_000
            )
        )

        #expect(fixedBucket.name == "Launch package")
        #expect(fixedBucket.billingMode == .fixed)
        #expect(fixedBucket.fixedAmountMinorUnits == 240_000)
        #expect(retainerBucket.billingMode == .retainer)
        #expect(retainerBucket.retainerAmountMinorUnits == 160_000)
        #expect(retainerBucket.retainerPeriodLabel == "Monthly")
        #expect(retainerBucket.retainerIncludedMinutes == 600)
        #expect(retainerBucket.retainerOverageRateMinorUnits == 12_000)

        let updatedFixedBucket = try store.updateBucket(
            projectID: projectID,
            bucketID: fixedBucket.id,
            WorkspaceBucketDraft(
                name: "Launch package revised",
                billingMode: .retainer,
                hourlyRateMinorUnits: 0,
                fixedAmountMinorUnits: 275_000,
                retainerAmountMinorUnits: 99_000
            )
        )

        #expect(updatedFixedBucket.billingMode == .fixed)
        #expect(updatedFixedBucket.name == "Launch package revised")
        #expect(updatedFixedBucket.fixedAmountMinorUnits == 275_000)
        #expect(updatedFixedBucket.retainerAmountMinorUnits == nil)
        #expect(throws: WorkspaceStoreError.invalidTimeEntry) {
            try store.addTimeEntry(
                projectID: projectID,
                bucketID: fixedBucket.id,
                draft: WorkspaceTimeEntryDraft(
                    date: Date.billbiDate(year: 2026, month: 4, day: 27),
                    timeInput: "1h",
                    description: "Should stay amount-only",
                    isBillable: true
                )
            )
        }
        #expect(throws: WorkspaceStoreError.invalidFixedCost) {
            try store.addFixedCost(
                projectID: projectID,
                bucketID: fixedBucket.id,
                draft: WorkspaceFixedCostDraft(
                    date: Date.billbiDate(year: 2026, month: 4, day: 27),
                    description: "Should stay amount-only",
                    amountMinorUnits: 10_000
                )
            )
        }
    }

    @Test func workspaceStoreNormalizesMissingRatesForExistingActiveBuckets() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000852")!
        let openBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000852")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Rate repair",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: UUID(uuidString: "30000000-0000-0000-0000-000000000851")!,
                            name: "Known rate",
                            status: .ready,
                            totalMinorUnits: 60_000,
                            billableMinutes: 180,
                            fixedCostMinorUnits: 0
                        ),
                        WorkspaceBucket(
                            id: openBucketID,
                            name: "Imported active work",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    date: Date.billbiDate(year: 2026, month: 4, day: 27),
                                    startTime: "10:00",
                                    endTime: "12:00",
                                    durationMinutes: 120,
                                    description: "Recovered billable work",
                                    hourlyRateMinorUnits: 0
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))

        let project = try #require(store.workspace.projects.first)
        let bucket = try #require(project.buckets.first { $0.id == openBucketID })
        #expect(bucket.hourlyRateMinorUnits == 20_000)
        #expect(bucket.timeEntries.first?.hourlyRateMinorUnits == 20_000)
        #expect(bucket.effectiveTotalMinorUnits == 40_000)
    }

    @Test func inMemoryWorkspaceStoreArchivesAndRestoresProjects() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000851")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Lifecycle project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let archiveDate = Date.billbiDate(year: 2026, month: 4, day: 27)
        let restoreDate = Date.billbiDate(year: 2026, month: 4, day: 28)

        try store.archiveProject(projectID: projectID, occurredAt: archiveDate)
        #expect(store.workspace.projects.first?.isArchived == true)
        #expect(store.workspace.activeProjects.isEmpty)
        #expect(store.workspace.archivedProjects.map(\.id) == [projectID])

        try store.restoreProject(projectID: projectID, occurredAt: restoreDate)
        #expect(store.workspace.projects.first?.isArchived == false)
        #expect(store.workspace.activeProjects.map(\.id) == [projectID])
        #expect(store.workspace.archivedProjects.isEmpty)
        #expect(store.workspace.activity.map(\.message) == [
            "Lifecycle project archived",
            "Lifecycle project restored",
        ])
        #expect(store.workspace.activity.map(\.occurredAt) == [
            archiveDate,
            restoreDate,
        ])
    }

    @Test func inMemoryWorkspaceStoreRemovesArchivedProjects() throws {
        let archivedProjectID = UUID(uuidString: "20000000-0000-0000-0000-000000000855")!
        let activeProjectID = UUID(uuidString: "20000000-0000-0000-0000-000000000856")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: archivedProjectID,
                    name: "Old project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: true,
                    buckets: [],
                    invoices: []
                ),
                WorkspaceProject(
                    id: activeProjectID,
                    name: "Current project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let removeDate = Date.billbiDate(year: 2026, month: 4, day: 29)

        try store.removeProject(projectID: archivedProjectID, occurredAt: removeDate)

        #expect(store.workspace.projects.map(\.id) == [activeProjectID])
        #expect(store.workspace.activity.map(\.message) == ["Old project project removed"])
        #expect(store.workspace.activity.map(\.detail) == ["Happ.ines"])
        #expect(store.workspace.activity.map(\.occurredAt) == [removeDate])
    }

    @Test func inMemoryWorkspaceStoreOnlyRemovesArchivedProjects() throws {
        let activeProjectID = UUID(uuidString: "20000000-0000-0000-0000-000000000857")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: activeProjectID,
                    name: "Guard project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        ))

        #expect(throws: WorkspaceStoreError.projectNotArchived) {
            try store.removeProject(projectID: activeProjectID)
        }
        #expect(store.workspace.projects.map(\.id) == [activeProjectID])
        #expect(store.workspace.activity.isEmpty)
    }

    @Test func inMemoryWorkspaceStoreArchivesAndRestoresBuckets() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000852")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000852")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Lifecycle project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Lifecycle bucket",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let archiveDate = Date.billbiDate(year: 2026, month: 4, day: 27)
        let restoreDate = Date.billbiDate(year: 2026, month: 4, day: 28)

        try store.archiveBucket(projectID: projectID, bucketID: bucketID, occurredAt: archiveDate)
        #expect(store.workspace.projects.first?.buckets.first?.status == .archived)

        try store.restoreBucket(projectID: projectID, bucketID: bucketID, occurredAt: restoreDate)
        #expect(store.workspace.projects.first?.buckets.first?.status == .open)
        #expect(store.workspace.activity.map(\.message) == [
            "Lifecycle bucket archived",
            "Lifecycle bucket restored",
        ])
        #expect(store.workspace.activity.map(\.occurredAt) == [
            archiveDate,
            restoreDate,
        ])
    }

    @Test func inMemoryWorkspaceStoreRemovesArchivedBuckets() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000853")!
        let archivedBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000853")!
        let openBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000854")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Removal project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: archivedBucketID,
                            name: "Old scope",
                            status: .archived,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                        WorkspaceBucket(
                            id: openBucketID,
                            name: "Current scope",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let removeDate = Date.billbiDate(year: 2026, month: 4, day: 29)

        try store.removeBucket(projectID: projectID, bucketID: archivedBucketID, occurredAt: removeDate)

        #expect(store.workspace.projects.first?.buckets.map(\.id) == [openBucketID])
        #expect(store.workspace.activity.map(\.message) == ["Old scope removed"])
        #expect(store.workspace.activity.map(\.detail) == ["Removal project"])
        #expect(store.workspace.activity.map(\.occurredAt) == [removeDate])
    }

    @Test func inMemoryWorkspaceStoreOnlyRemovesArchivedBuckets() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000854")!
        let openBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000855")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Removal guard project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: openBucketID,
                            name: "Current scope",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))

        #expect(throws: WorkspaceStoreError.bucketLocked(.open)) {
            try store.removeBucket(projectID: projectID, bucketID: openBucketID)
        }
        #expect(store.workspace.projects.first?.buckets.map(\.id) == [openBucketID])
        #expect(store.workspace.activity.isEmpty)
    }

    @Test func inMemoryWorkspaceStoreUpdatesProjectMetadataWithoutRewritingHistory() throws {
        let originalClientID = try #require(WorkspaceFixtures.demoWorkspace.clients.first?.id)
        let updatedClientName = try #require(WorkspaceFixtures.demoWorkspace.clients.last?.name)
        let updatedClientID = try #require(WorkspaceFixtures.demoWorkspace.clients.last?.id)
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000861")!
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000861")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000861")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: originalClientID,
                    name: "Original project",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Existing bucket",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: [
                        WorkspaceInvoice(
                            id: invoiceID,
                            number: "EHX-2026-861",
                            clientName: "Happ.ines",
                            projectName: "Original project",
                            bucketName: "Existing bucket",
                            issueDate: Date.billbiDate(year: 2026, month: 4, day: 1),
                            dueDate: Date.billbiDate(year: 2026, month: 4, day: 15),
                            status: .finalized,
                            totalMinorUnits: 12_000
                        ),
                    ]
                ),
            ],
            activity: []
        ))
        let occurredAt = Date.billbiDate(year: 2026, month: 4, day: 27)

        let project = try store.updateProject(
            projectID: projectID,
            WorkspaceProjectUpdateDraft(
                name: "  Retainer work  ",
                clientID: updatedClientID,
                currencyCode: " usd "
            ),
            occurredAt: occurredAt
        )

        #expect(project.id == projectID)
        #expect(project.name == "Retainer work")
        #expect(project.clientName == updatedClientName)
        #expect(project.currencyCode == "USD")
        #expect(project.buckets.map(\.id) == [bucketID])
        #expect(project.invoices.map(\.projectName) == ["Original project"])
        #expect(store.workspace.projects.first == project)
        #expect(store.workspace.activity.map(\.message) == ["Retainer work project updated"])
        #expect(store.workspace.activity.first?.occurredAt == occurredAt)
    }

    @Test func inMemoryWorkspaceStoreCreatesClientAndRecordsActivity() throws {
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [],
            projects: [],
            activity: []
        ))
        let date = Date.billbiDate(year: 2026, month: 4, day: 27)

        let client = try store.createClient(
            WorkspaceClientDraft(
                name: "  Studio North  ",
                email: "  billing@studionorth.example  ",
                billingAddress: "  12 Example Street  ",
                defaultTermsDays: 30
            ),
            occurredAt: date
        )

        #expect(client.name == "Studio North")
        #expect(client.email == "billing@studionorth.example")
        #expect(client.billingAddress == "12 Example Street")
        #expect(client.defaultTermsDays == 30)
        #expect(store.workspace.clients.map(\.id) == [client.id])
        #expect(store.workspace.activity.map(\.message) == ["Studio North client created"])
    }

    @Test func inMemoryWorkspaceStoreUpdatesClientAndProjectReferences() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000811")!
        let unrelatedClientID = UUID(uuidString: "10000000-0000-0000-0000-000000000812")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Original Client",
                    email: "billing@original.example",
                    billingAddress: "1 Original Street",
                    defaultTermsDays: 14
                ),
                WorkspaceClient(
                    id: unrelatedClientID,
                    name: "Other Client",
                    email: "billing@other.example",
                    billingAddress: "2 Other Street",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000811")!,
                    clientID: clientID,
                    name: "Matching project",
                    clientName: "Original Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000812")!,
                    clientID: unrelatedClientID,
                    name: "Other project",
                    clientName: "Original Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let occurredAt = Date.billbiDate(year: 2026, month: 4, day: 27)

        let client = try store.updateClient(
            clientID: clientID,
            WorkspaceClientDraft(
                name: "  Renamed Client  ",
                email: "  billing@renamed.example  ",
                billingAddress: "  8 Renamed Avenue  ",
                defaultTermsDays: 30
            ),
            occurredAt: occurredAt
        )

        #expect(client.id == clientID)
        #expect(client.name == "Renamed Client")
        #expect(client.email == "billing@renamed.example")
        #expect(client.billingAddress == "8 Renamed Avenue")
        #expect(client.defaultTermsDays == 30)
        #expect(store.workspace.clients.first == client)
        #expect(store.workspace.projects.map(\.clientName) == [
            "Renamed Client",
            "Original Client",
        ])
        #expect(store.workspace.activity.map(\.message) == ["Renamed Client client updated"])
        #expect(store.workspace.activity.first?.detail == "billing@renamed.example")
        #expect(store.workspace.activity.first?.occurredAt == occurredAt)
    }

    @Test func inMemoryWorkspaceStoreAllowsRemovingArchivedClientWhenOnlyNameMatchesProjects() throws {
        let removableClientID = UUID(uuidString: "10000000-0000-0000-0000-000000000841")!
        let otherClientID = UUID(uuidString: "10000000-0000-0000-0000-000000000842")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: removableClientID,
                    name: "Northstar Labs",
                    email: "billing@northstar.example",
                    billingAddress: "1 Main Street",
                    defaultTermsDays: 14,
                    isArchived: true
                ),
                WorkspaceClient(
                    id: otherClientID,
                    name: "Other Client",
                    email: "billing@other.example",
                    billingAddress: "2 Side Street",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000841")!,
                    clientID: otherClientID,
                    name: "Name collision project",
                    clientName: "Northstar Labs",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        ))

        try store.removeClient(clientID: removableClientID)

        #expect(store.workspace.clients.map(\.id) == [otherClientID])
    }

    @Test func persistentWorkspaceStoreSavesClientUpdates() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000821")!
        let store = WorkspaceStore(
            seed: WorkspaceSnapshot(
                businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
                clients: [
                    WorkspaceClient(
                        id: clientID,
                        name: "Stored Client",
                        email: "billing@stored.example",
                        billingAddress: "4 Stored Street",
                        defaultTermsDays: 21
                    ),
                ],
                projects: [
                    WorkspaceProject(
                        id: UUID(uuidString: "20000000-0000-0000-0000-000000000821")!,
                        clientID: clientID,
                        name: "Stored project",
                        clientName: "Stored Client",
                        currencyCode: "EUR",
                        isArchived: false,
                        buckets: [],
                        invoices: []
                    ),
                ],
                activity: []
            ),
            modelContext: modelContext
        )

        try store.updateClient(
            clientID: clientID,
            WorkspaceClientDraft(
                name: "Stored Client Updated",
                email: "billing@updated.example",
                billingAddress: "9 Updated Lane",
                defaultTermsDays: 45
            )
        )

        let relaunchedStore = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace, modelContext: modelContext)
        #expect(relaunchedStore.workspace.clients.first?.name == "Stored Client Updated")
        #expect(relaunchedStore.workspace.clients.first?.email == "billing@updated.example")
        #expect(relaunchedStore.workspace.clients.first?.billingAddress == "9 Updated Lane")
        #expect(relaunchedStore.workspace.clients.first?.defaultTermsDays == 45)
        #expect(relaunchedStore.workspace.projects.first?.clientName == "Stored Client Updated")
    }

    @Test func persistentWorkspaceStoreMutatesNormalizedProjectClientLinksByID() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let originalClientID = UUID(uuidString: "10000000-0000-0000-0000-000000000851")!
        let replacementClientID = UUID(uuidString: "10000000-0000-0000-0000-000000000852")!
        let createdAt = Date.billbiDate(year: 2026, month: 4, day: 27)
        modelContext.insert(ClientRecord(
            id: originalClientID,
            name: "Original Client",
            email: "billing@original.example",
            billingAddress: "1 Original Street",
            defaultTermsDays: 14,
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        modelContext.insert(ClientRecord(
            id: replacementClientID,
            name: "Replacement Client",
            email: "billing@replacement.example",
            billingAddress: "2 Replacement Street",
            defaultTermsDays: 30,
            createdAt: createdAt,
            updatedAt: createdAt
        ))
        try modelContext.save()

        let store = WorkspaceStore(seed: WorkspaceSnapshot.empty, modelContext: modelContext)
        let createdProject = try store.createProject(WorkspaceProjectDraft(
            name: "Client portal",
            clientID: originalClientID,
            currencyCode: "EUR",
            firstBucketName: "MVP",
            hourlyRateMinorUnits: 12_000
        ))

        #expect(createdProject.clientID == originalClientID)
        #expect(createdProject.clientName == "Original Client")

        let updatedProject = try store.updateProject(
            projectID: createdProject.id,
            WorkspaceProjectUpdateDraft(
                name: "Client portal v2",
                clientID: replacementClientID,
                currencyCode: "USD"
            )
        )

        #expect(updatedProject.clientID == replacementClientID)
        #expect(updatedProject.clientName == "Replacement Client")
        #expect(updatedProject.currencyCode == "USD")

        try store.updateClient(clientID: replacementClientID, WorkspaceClientDraft(
            name: "Replacement Client Renamed",
            email: "billing@replacement.example",
            billingAddress: "2 Replacement Street",
            defaultTermsDays: 30
        ))

        let relaunchedStore = WorkspaceStore(seed: WorkspaceSnapshot.empty, modelContext: modelContext)
        #expect(relaunchedStore.workspace.projects.first?.clientID == replacementClientID)
        #expect(relaunchedStore.workspace.projects.first?.clientName == "Replacement Client Renamed")
    }

    @Test func persistentWorkspaceStoreMutatesNormalizedBucketEntriesAndReopensReadyBucketsOnEdit() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000871")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000871")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000871")!
        let createdAt = Date.billbiDate(year: 2026, month: 4, day: 28)
        let fixedCostDate = Date.billbiDate(year: 2026, month: 4, day: 29)
        let rangeEntryDate = Date.billbiDate(year: 2026, month: 4, day: 30)

        let client = ClientRecord(
            id: clientID,
            name: "Northstar Labs",
            email: "billing@northstar.example",
            billingAddress: "1 Main Street",
            defaultTermsDays: 14,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Mutation rewrite",
            currencyCode: "EUR",
            createdAt: createdAt,
            updatedAt: createdAt,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Sprint 2",
            statusRaw: BucketStatus.open.rawValue,
            createdAt: createdAt,
            updatedAt: createdAt,
            project: project
        )
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        try store.addTimeEntry(
            projectID: projectID,
            bucketID: bucketID,
            draft: WorkspaceTimeEntryDraft(
                date: createdAt,
                timeInput: "1h",
                description: "Planning",
                isBillable: false
            )
        )
        try store.addFixedCost(
            projectID: projectID,
            bucketID: bucketID,
            draft: WorkspaceFixedCostDraft(
                date: fixedCostDate,
                description: "Prototype hosting",
                amountMinorUnits: 5_000
            )
        )
        try store.markBucketReady(
            projectID: projectID,
            bucketID: bucketID
        )
        try store.addTimeEntry(
            projectID: projectID,
            bucketID: bucketID,
            draft: WorkspaceTimeEntryDraft(
                date: rangeEntryDate,
                timeInput: "13:15-14:45",
                description: "QA handoff",
                isBillable: false
            )
        )

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let reloadedProject = try #require(reloadedStore.workspace.projects.first)
        let reloadedBucket = try #require(reloadedProject.buckets.first)

        #expect(reloadedBucket.status == .open)
        #expect(reloadedBucket.timeEntries.map(\.description) == ["Planning", "QA handoff"])
        #expect(reloadedBucket.timeEntries.map(\.durationMinutes) == [60, 90])
        #expect(reloadedBucket.timeEntries.map(\.timeRangeLabel) == ["1h", "13:15-14:45"])
        #expect(reloadedBucket.effectiveNonBillableMinutes == 150)
        #expect(reloadedBucket.effectiveFixedCostMinorUnits == 5_000)
        #expect(reloadedBucket.effectiveTotalMinorUnits == 5_000)

        let persistedTimeEntries = try reloadedStore.timeEntryRecords(for: bucketID)
            .sorted(by: { $0.createdAt < $1.createdAt })
        let durationOnly = try #require(persistedTimeEntries.first(where: { $0.descriptionText == "Planning" }))
        let rangeEntry = try #require(persistedTimeEntries.first(where: { $0.descriptionText == "QA handoff" }))

        #expect(durationOnly.startMinuteOfDay == nil)
        #expect(durationOnly.endMinuteOfDay == nil)
        #expect(durationOnly.durationMinutes == 60)
        #expect(durationOnly.isBillable == false)
        #expect(rangeEntry.startMinuteOfDay == 13 * 60 + 15)
        #expect(rangeEntry.endMinuteOfDay == 14 * 60 + 45)
        #expect(rangeEntry.durationMinutes == 90)
        #expect(rangeEntry.isBillable == false)

        let fixedCosts = try reloadedStore.fixedCostRecords(for: bucketID)
        let fixedCost = try #require(fixedCosts.first(where: { $0.descriptionText == "Prototype hosting" }))
        #expect(fixedCost.quantity == 1)
        #expect(fixedCost.unitPriceMinorUnits == 5_000)
        #expect(fixedCost.isBillable)
    }

    @Test func persistentWorkspaceStoreUpdatesNormalizedEntryDatesAndReopensReadyBucket() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000876")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000876")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000876")!
        let timeEntryID = UUID(uuidString: "70000000-0000-0000-0000-000000000876")!
        let fixedCostID = UUID(uuidString: "80000000-0000-0000-0000-000000000876")!
        let createdAt = Date.billbiDate(year: 2026, month: 4, day: 28)
        let timeDate = Date.billbiDate(year: 2026, month: 5, day: 1)
        let costDate = Date.billbiDate(year: 2026, month: 5, day: 2)

        let client = ClientRecord(
            id: clientID,
            name: "Northstar Labs",
            email: "billing@northstar.example",
            billingAddress: "1 Main Street",
            defaultTermsDays: 14,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Entry date rewrite",
            currencyCode: "EUR",
            createdAt: createdAt,
            updatedAt: createdAt,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Sprint dates",
            statusRaw: BucketStatus.ready.rawValue,
            defaultHourlyRateMinorUnits: 8_000,
            createdAt: createdAt,
            updatedAt: createdAt,
            project: project
        )
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(TimeEntryRecord(
            id: timeEntryID,
            bucketID: bucketID,
            workDate: createdAt,
            durationMinutes: 60,
            descriptionText: "Existing time",
            isBillable: true,
            hourlyRateMinorUnits: 8_000,
            createdAt: createdAt,
            updatedAt: createdAt,
            bucket: bucket
        ))
        modelContext.insert(FixedCostRecord(
            id: fixedCostID,
            bucketID: bucketID,
            date: createdAt,
            descriptionText: "Existing cost",
            quantity: 1,
            unitPriceMinorUnits: 1_000,
            isBillable: true,
            createdAt: createdAt,
            updatedAt: createdAt,
            bucket: bucket
        ))
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        try store.updateEntryDate(
            projectID: projectID,
            bucketID: bucketID,
            rowID: timeEntryID,
            kind: .time,
            date: timeDate
        )
        try store.updateEntryDate(
            projectID: projectID,
            bucketID: bucketID,
            rowID: fixedCostID,
            kind: .fixedCost,
            date: costDate
        )

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let reloadedBucket = try #require(reloadedStore.workspace.projects.first?.buckets.first)
        #expect(reloadedBucket.status == .open)
        #expect(reloadedBucket.timeEntries.first?.date == timeDate)
        #expect(reloadedBucket.fixedCostEntries.first?.date == costDate)

        let persistedTime = try #require(try reloadedStore.timeEntryRecords(for: bucketID).first)
        let persistedCost = try #require(try reloadedStore.fixedCostRecords(for: bucketID).first)
        #expect(persistedTime.workDate == timeDate)
        #expect(persistedCost.date == costDate)
        #expect(persistedTime.descriptionText == "Existing time")
        #expect(persistedCost.unitPriceMinorUnits == 1_000)
    }

    @Test func persistentWorkspaceStoreRejectsNormalizedEntryMutationsWhenBucketRecordBecomesLocked() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000874")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000874")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000874")!
        let timeEntryID = UUID(uuidString: "70000000-0000-0000-0000-000000000874")!
        let fixedCostID = UUID(uuidString: "80000000-0000-0000-0000-000000000874")!
        let createdAt = Date.billbiDate(year: 2026, month: 4, day: 28)

        let client = ClientRecord(
            id: clientID,
            name: "Northstar Labs",
            email: "billing@northstar.example",
            billingAddress: "1 Main Street",
            defaultTermsDays: 14,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Bucket lock guard",
            currencyCode: "EUR",
            createdAt: createdAt,
            updatedAt: createdAt,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Sprint 3",
            statusRaw: BucketStatus.open.rawValue,
            defaultHourlyRateMinorUnits: 8_000,
            createdAt: createdAt,
            updatedAt: createdAt,
            project: project
        )
        let timeEntry = TimeEntryRecord(
            id: timeEntryID,
            bucketID: bucketID,
            workDate: createdAt,
            durationMinutes: 60,
            descriptionText: "Existing time",
            isBillable: true,
            hourlyRateMinorUnits: 8_000,
            createdAt: createdAt,
            updatedAt: createdAt,
            bucket: bucket
        )
        let fixedCost = FixedCostRecord(
            id: fixedCostID,
            bucketID: bucketID,
            date: createdAt,
            descriptionText: "Existing cost",
            quantity: 1,
            unitPriceMinorUnits: 1_000,
            isBillable: true,
            createdAt: createdAt,
            updatedAt: createdAt,
            bucket: bucket
        )
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        modelContext.insert(timeEntry)
        modelContext.insert(fixedCost)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        #expect(store.workspace.projects.first?.buckets.first?.status == .open)

        let lockedAt = Date.billbiDate(year: 2026, month: 4, day: 29)
        let bucketRecord = try #require(try store.bucketRecord(bucketID))
        bucketRecord.status = .archived
        bucketRecord.updatedAt = lockedAt
        try modelContext.save()

        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try store.addTimeEntry(
                projectID: projectID,
                bucketID: bucketID,
                draft: WorkspaceTimeEntryDraft(
                    date: lockedAt,
                    timeInput: "1h",
                    description: "Should fail",
                    isBillable: true
                )
            )
        }
        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try store.addFixedCost(
                projectID: projectID,
                bucketID: bucketID,
                draft: WorkspaceFixedCostDraft(
                    date: lockedAt,
                    description: "Should fail",
                    amountMinorUnits: 2_500
                )
            )
        }
        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try store.deleteEntry(
                projectID: projectID,
                bucketID: bucketID,
                rowID: timeEntryID,
                kind: .time,
                isBillable: true
            )
        }
        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try store.deleteEntry(
                projectID: projectID,
                bucketID: bucketID,
                rowID: fixedCostID,
                kind: .fixedCost,
                isBillable: true
            )
        }
        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try store.updateEntryDate(
                projectID: projectID,
                bucketID: bucketID,
                rowID: timeEntryID,
                kind: .time,
                date: lockedAt
            )
        }
        #expect(throws: WorkspaceStoreError.bucketLocked(.archived)) {
            try store.updateEntryDate(
                projectID: projectID,
                bucketID: bucketID,
                rowID: fixedCostID,
                kind: .fixedCost,
                date: lockedAt
            )
        }

        #expect((try store.timeEntryRecords(for: bucketID)).count == 1)
        #expect((try store.fixedCostRecords(for: bucketID)).count == 1)
    }

    @Test func persistentWorkspaceStoreMutatesNormalizedBucketLifecycleRecords() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000872")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000872")!
        let existingBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000872")!
        let createdAt = Date.billbiDate(year: 2026, month: 4, day: 28)

        let client = ClientRecord(
            id: clientID,
            name: "Northstar Labs",
            email: "billing@northstar.example",
            billingAddress: "1 Main Street",
            defaultTermsDays: 14,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Bucket lifecycle",
            currencyCode: "EUR",
            createdAt: createdAt,
            updatedAt: createdAt,
            client: client
        )
        let existingBucket = BucketRecord(
            id: existingBucketID,
            projectID: projectID,
            name: "Existing",
            statusRaw: BucketStatus.open.rawValue,
            createdAt: createdAt,
            updatedAt: createdAt,
            project: project
        )
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(existingBucket)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let createdBucket = try store.createBucket(
            projectID: projectID,
            WorkspaceBucketDraft(name: "May sprint", hourlyRateMinorUnits: 9_000)
        )
        let updatedBucket = try store.updateBucket(
            projectID: projectID,
            bucketID: createdBucket.id,
            WorkspaceBucketDraft(name: "June sprint", hourlyRateMinorUnits: 9_000)
        )

        #expect(throws: WorkspaceStoreError.bucketLocked(.open)) {
            try store.removeBucket(projectID: projectID, bucketID: updatedBucket.id)
        }

        try store.archiveBucket(projectID: projectID, bucketID: updatedBucket.id)
        try store.restoreBucket(projectID: projectID, bucketID: updatedBucket.id)
        try store.archiveBucket(projectID: projectID, bucketID: updatedBucket.id)
        try store.removeBucket(projectID: projectID, bucketID: updatedBucket.id)

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let reloadedProject = try #require(reloadedStore.workspace.projects.first)
        #expect(reloadedProject.buckets.map(\.id) == [existingBucketID])
        #expect(reloadedProject.buckets.map(\.name) == ["Existing"])

        let persistedBucketRecords = try reloadedStore.bucketRecords(for: projectID)
        #expect(persistedBucketRecords.count == 1)
        #expect(persistedBucketRecords.first?.id == existingBucketID)
    }

    @Test func persistentWorkspaceStorePersistsNormalizedBucketDefaultRateAcrossCreateAndUpdate() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000873")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000873")!
        let createdAt = Date.billbiDate(year: 2026, month: 4, day: 28)

        let client = ClientRecord(
            id: clientID,
            name: "Northstar Labs",
            email: "billing@northstar.example",
            billingAddress: "1 Main Street",
            defaultTermsDays: 14,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Bucket rate persistence",
            currencyCode: "EUR",
            createdAt: createdAt,
            updatedAt: createdAt,
            client: client
        )
        modelContext.insert(client)
        modelContext.insert(project)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let bucket = try store.createBucket(
            projectID: projectID,
            WorkspaceBucketDraft(name: "Rate bucket", hourlyRateMinorUnits: 9_000)
        )
        _ = try store.updateBucket(
            projectID: projectID,
            bucketID: bucket.id,
            WorkspaceBucketDraft(name: "Rate bucket", hourlyRateMinorUnits: 11_000)
        )
        try store.addTimeEntry(
            projectID: projectID,
            bucketID: bucket.id,
            draft: WorkspaceTimeEntryDraft(
                date: createdAt,
                timeInput: "1h",
                description: "Billable polish",
                isBillable: true
            )
        )

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let reloadedProject = try #require(reloadedStore.workspace.projects.first)
        let reloadedBucket = try #require(reloadedProject.buckets.first(where: { $0.id == bucket.id }))
        let reloadedEntry = try #require(reloadedBucket.timeEntries.first {
            $0.description == "Billable polish"
        })

        #expect(reloadedBucket.hourlyRateMinorUnits == 11_000)
        #expect(reloadedEntry.hourlyRateMinorUnits == 11_000)
    }

    @Test func persistentWorkspaceStoreUsesPersistedBucketDefaultRateForStaleProjectionTimeEntryMutation() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000875")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000875")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000875")!
        let createdAt = Date.billbiDate(year: 2026, month: 4, day: 28)

        let client = ClientRecord(
            id: clientID,
            name: "Northstar Labs",
            email: "billing@northstar.example",
            billingAddress: "1 Main Street",
            defaultTermsDays: 14,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let project = ProjectRecord(
            id: projectID,
            clientID: clientID,
            name: "Stale projection rate",
            currencyCode: "EUR",
            createdAt: createdAt,
            updatedAt: createdAt,
            client: client
        )
        let bucket = BucketRecord(
            id: bucketID,
            projectID: projectID,
            name: "Sprint 4",
            statusRaw: BucketStatus.open.rawValue,
            defaultHourlyRateMinorUnits: 8_000,
            createdAt: createdAt,
            updatedAt: createdAt,
            project: project
        )
        modelContext.insert(client)
        modelContext.insert(project)
        modelContext.insert(bucket)
        try modelContext.save()

        let store = WorkspaceStore(seed: .empty, modelContext: modelContext)

        let persistedBucketRecord = try #require(try store.bucketRecord(bucketID))
        persistedBucketRecord.defaultHourlyRateMinorUnits = 12_500
        persistedBucketRecord.updatedAt = Date.billbiDate(year: 2026, month: 4, day: 29)
        try modelContext.save()

        try store.addTimeEntry(
            projectID: projectID,
            bucketID: bucketID,
            draft: WorkspaceTimeEntryDraft(
                date: createdAt,
                timeInput: "1h",
                description: "Rate should come from persisted default",
                isBillable: true
            )
        )

        let reloadedStore = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let persistedEntries = try reloadedStore.timeEntryRecords(for: bucketID)
        let persistedEntry = try #require(persistedEntries.first)
        #expect(persistedEntry.hourlyRateMinorUnits == 12_500)

        let projectedBucket = try #require(reloadedStore.workspace.projects.first?.buckets.first)
        let projectedEntry = try #require(projectedBucket.timeEntries.first)
        #expect(projectedEntry.hourlyRateMinorUnits == 12_500)
    }

    @Test func inMemoryWorkspaceStoreRejectsInvalidClientUpdatesWithoutMutation() {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000831")!
        let originalWorkspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Stable Client",
                    email: "billing@stable.example",
                    billingAddress: "5 Stable Street",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000831")!,
                    name: "Stable project",
                    clientName: "Stable Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        )
        let store = WorkspaceStore(seed: originalWorkspace)

        #expect(throws: WorkspaceStoreError.invalidClient) {
            try store.updateClient(clientID: clientID, WorkspaceClientDraft(
                name: "",
                email: "billing@valid.example",
                billingAddress: "1 Valid Street",
                defaultTermsDays: 14
            ))
        }

        #expect(throws: WorkspaceStoreError.invalidClient) {
            try store.updateClient(clientID: clientID, WorkspaceClientDraft(
                name: "Valid Client",
                email: "   ",
                billingAddress: "1 Valid Street",
                defaultTermsDays: 14
            ))
        }

        #expect(throws: WorkspaceStoreError.invalidClient) {
            try store.updateClient(clientID: clientID, WorkspaceClientDraft(
                name: "Valid Client",
                email: "billing@valid.example",
                billingAddress: "",
                defaultTermsDays: 14
            ))
        }

        #expect(throws: WorkspaceStoreError.invalidClient) {
            try store.updateClient(clientID: clientID, WorkspaceClientDraft(
                name: "Valid Client",
                email: "billing@valid.example",
                billingAddress: "1 Valid Street",
                defaultTermsDays: 0
            ))
        }

        #expect(store.workspace == originalWorkspace)
    }

    @Test func inMemoryWorkspaceStoreRejectsInvalidClientDrafts() {
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [],
            projects: [],
            activity: []
        ))

        #expect(throws: WorkspaceStoreError.invalidClient) {
            try store.createClient(WorkspaceClientDraft(
                name: "",
                email: "billing@example.com",
                billingAddress: "1 Main Street",
                defaultTermsDays: 14
            ))
        }

        #expect(throws: WorkspaceStoreError.invalidClient) {
            try store.createClient(WorkspaceClientDraft(
                name: "Client",
                email: "billing@example.com",
                billingAddress: "1 Main Street",
                defaultTermsDays: 0
            ))
        }

        #expect(store.workspace.clients.isEmpty)
        #expect(store.workspace.activity.isEmpty)
    }

    @Test func inMemoryWorkspaceStoreAllowsNameOnlyClientAfterSkippedOnboarding() throws {
        var workspace = WorkspaceSnapshot.empty
        workspace.onboardingCompleted = true
        let store = WorkspaceStore(seed: workspace)

        let client = try store.createClient(WorkspaceClientDraft(
            name: "Bikepark Thunersee",
            email: "",
            billingAddress: "",
            defaultTermsDays: 14
        ))

        #expect(client.name == "Bikepark Thunersee")
        #expect(client.email == "")
        #expect(client.billingAddress == "")
        #expect(store.workspace.clients.map(\.id) == [client.id])
    }

    @Test func inMemoryWorkspaceStoreDefaultsBlankFirstBucketWhenCreatingProjectAfterSkippedOnboarding() throws {
        var workspace = WorkspaceSnapshot.empty
        workspace.onboardingCompleted = true
        workspace.clients = [
            WorkspaceClient(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000901")!,
                name: "Bikepark Thunersee",
                email: "",
                billingAddress: "",
                defaultTermsDays: 14
            ),
        ]
        let store = WorkspaceStore(seed: workspace)
        let client = try #require(store.workspace.clients.first)

        let project = try store.createProject(WorkspaceProjectDraft(
            name: "Launch Site",
            clientID: client.id,
            currencyCode: "EUR",
            firstBucketName: " ",
            hourlyRateMinorUnits: 8_000
        ))

        #expect(project.name == "Launch Site")
        #expect(project.buckets.map(\.name) == ["General"])
    }

    @Test func persistentWorkspaceStoreUpdatesBusinessProfileAndInvoiceDefaults() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000901")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000901")!
        let issueDate = Date.billbiDate(year: 2026, month: 5, day: 4)
        let store = WorkspaceStore(
            seed: WorkspaceSnapshot(
                businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
                clients: [],
                projects: [
                    WorkspaceProject(
                        id: projectID,
                        name: "Settings defaults",
                        clientName: "Unmatched Client",
                        currencyCode: "EUR",
                        isArchived: false,
                        buckets: [
                            WorkspaceBucket(
                                id: bucketID,
                                name: "Ready defaults",
                                status: .ready,
                                totalMinorUnits: 20_000,
                                billableMinutes: 120,
                                fixedCostMinorUnits: 0
                            ),
                        ],
                        invoices: []
                    ),
                ],
                activity: []
            ),
            modelContext: modelContext
        )

        try store.updateBusinessProfile(WorkspaceBusinessProfileDraft(
            businessName: "  North Coast Studio  ",
            email: "  invoices@north.example  ",
            phone: "",
            address: "  9 Harbour Road  ",
            taxIdentifier: "  DE123456789  ",
            countryCode: " us ",
            invoicePrefix: "  NCS  ",
            nextInvoiceNumber: 42,
            currencyCode: "  usd  ",
            paymentDetails: "  ACH 123456  ",
            taxNote: "  VAT not applicable.  ",
            defaultTermsDays: 21
        ))

        let draft = try store.defaultInvoiceDraft(
            projectID: projectID,
            bucketID: bucketID,
            issueDate: issueDate
        )
        let relaunchedStore = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace, modelContext: modelContext)

        #expect(store.workspace.businessProfile.businessName == "North Coast Studio")
        #expect(store.workspace.businessProfile.email == "invoices@north.example")
        #expect(store.workspace.businessProfile.address == "9 Harbour Road")
        #expect(store.workspace.businessProfile.invoicePrefix == "NCS")
        #expect(store.workspace.businessProfile.nextInvoiceNumber == 42)
        #expect(store.workspace.businessProfile.currencyCode == "USD")
        #expect(store.workspace.businessProfile.paymentDetails == "ACH 123456")
        #expect(store.workspace.businessProfile.taxNote == "VAT not applicable.")
        #expect(store.workspace.businessProfile.taxIdentifier == "DE123456789")
        #expect(store.workspace.businessProfile.countryCode == "US")
        #expect(store.workspace.businessProfile.defaultTermsDays == 21)
        #expect(draft.invoiceNumber == "NCS-2026-042")
        #expect(draft.template == .kleinunternehmerClassic)
        #expect(draft.dueDate == Date.billbiDate(year: 2026, month: 5, day: 25))
        #expect(draft.taxNote == "VAT not applicable.")
        #expect(relaunchedStore.workspace.businessProfile == store.workspace.businessProfile)
    }

    @Test func inMemoryWorkspaceStoreRejectsInvalidBusinessProfileDrafts() {
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [],
            projects: [],
            activity: []
        ))
        let originalProfile = store.workspace.businessProfile

        #expect(throws: WorkspaceStoreError.invalidBusinessProfile) {
            try store.updateBusinessProfile(WorkspaceBusinessProfileDraft(
                businessName: "",
                email: "billing@example.com",
                phone: "",
                address: "1 Main Street",
                taxIdentifier: "",
                invoicePrefix: "INV",
                nextInvoiceNumber: 1,
                currencyCode: "EUR",
                paymentDetails: "Bank transfer",
                taxNote: "VAT reverse charge.",
                defaultTermsDays: 14
            ))
        }

        #expect(throws: WorkspaceStoreError.invalidBusinessProfile) {
            try store.updateBusinessProfile(WorkspaceBusinessProfileDraft(
                businessName: "Studio",
                email: "billing@example.com",
                phone: "",
                address: "1 Main Street",
                taxIdentifier: "",
                invoicePrefix: "INV",
                nextInvoiceNumber: 0,
                currencyCode: "EUR",
                paymentDetails: "Bank transfer",
                taxNote: "VAT reverse charge.",
                defaultTermsDays: 14
            ))
        }

        #expect(throws: WorkspaceStoreError.invalidBusinessProfile) {
            try store.updateBusinessProfile(WorkspaceBusinessProfileDraft(
                businessName: "Studio",
                email: "billing@example.com",
                phone: "",
                address: "1 Main Street",
                taxIdentifier: "",
                invoicePrefix: "INV",
                nextInvoiceNumber: 1,
                currencyCode: "EUR",
                paymentDetails: "Bank transfer",
                taxNote: "VAT reverse charge.",
                defaultTermsDays: 0
            ))
        }

        #expect(store.workspace.businessProfile == originalProfile)
    }

    @Test func workspaceStoreMutatesSenderTaxLegalFields() throws {
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [],
            projects: [],
            activity: []
        ))

        try store.createSenderTaxLegalField(label: "VAT ID", value: "DE123")
        let created = try #require(store.workspace.businessProfile.senderTaxLegalFields.last)
        #expect(created.label == "VAT ID")
        #expect(created.value == "DE123")
        #expect(created.placement == .senderDetails)
        #expect(created.isVisible)

        try store.updateSenderTaxLegalField(
            id: created.id,
            label: "VAT Number",
            value: "DE999",
            placement: .footer,
            isVisible: false
        )

        let updated = try #require(
            store.workspace.businessProfile.senderTaxLegalFields.first(where: { $0.id == created.id })
        )
        #expect(updated.label == "VAT Number")
        #expect(updated.value == "DE999")
        #expect(updated.placement == .footer)
        #expect(!updated.isVisible)

        let ids = store.workspace.businessProfile.senderTaxLegalFields.map(\.id).reversed()
        try store.reorderSenderTaxLegalFields(Array(ids))
        #expect(store.workspace.businessProfile.senderTaxLegalFields.map(\.id) == Array(ids))
        #expect(store.workspace.businessProfile.senderTaxLegalFields.map(\.sortOrder) == Array(0..<ids.count))

        try store.setSenderTaxLegalFieldVisibility(id: created.id, isVisible: true)
        let visibilityUpdated = try #require(
            store.workspace.businessProfile.senderTaxLegalFields.first(where: { $0.id == created.id })
        )
        #expect(visibilityUpdated.isVisible)

        try store.deleteSenderTaxLegalField(id: created.id)
        #expect(store.workspace.businessProfile.senderTaxLegalFields.contains(where: { $0.id == created.id }) == false)
    }

    @Test func persistentWorkspaceStorePersistsSenderTaxLegalFields() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let store = WorkspaceStore(
            seed: WorkspaceSnapshot(
                businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
                clients: [],
                projects: [],
                activity: []
            ),
            modelContext: modelContext
        )

        try store.createSenderTaxLegalField(label: "VAT ID", value: "DE123", placement: .footer)
        let created = try #require(store.workspace.businessProfile.senderTaxLegalFields.last)
        try store.updateSenderTaxLegalField(
            id: created.id,
            label: "VAT Number",
            value: "DE999",
            placement: .senderDetails,
            isVisible: true
        )

        let reloaded = WorkspaceStore(seed: .empty, modelContext: modelContext)
        let reloadedField = try #require(
            reloaded.workspace.businessProfile.senderTaxLegalFields.first(where: { $0.id == created.id })
        )
        #expect(reloadedField.label == "VAT Number")
        #expect(reloadedField.value == "DE999")
        #expect(reloadedField.placement == .senderDetails)
        #expect(reloadedField.isVisible)
    }

    @Test func workspaceStoreMutatesRecipientTaxLegalFields() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000000955")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Client",
                    email: "billing@example.com",
                    billingAddress: "Road 1",
                    defaultTermsDays: 14
                ),
            ],
            projects: [],
            activity: []
        ))

        try store.createRecipientTaxLegalField(clientID: clientID, label: "VAT", value: "CH-123")
        let created = try #require(store.workspace.clients[0].recipientTaxLegalFields.first)
        #expect(created.placement == .recipientDetails)

        try store.updateRecipientTaxLegalField(
            clientID: clientID,
            fieldID: created.id,
            label: "VAT ID",
            value: "CH-999",
            placement: .footer,
            isVisible: false
        )
        let updated = try #require(store.workspace.clients[0].recipientTaxLegalFields.first)
        #expect(updated.label == "VAT ID")
        #expect(updated.value == "CH-999")
        #expect(updated.placement == .footer)
        #expect(!updated.isVisible)

        try store.deleteRecipientTaxLegalField(clientID: clientID, fieldID: created.id)
        #expect(store.workspace.clients[0].recipientTaxLegalFields.isEmpty)
    }

    @Test func inMemoryWorkspaceStoreCreatesBucketWithRateDefaults() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let project = try #require(store.workspace.project(named: "Launch sprint"))
        let date = Date.billbiDate(year: 2026, month: 4, day: 27)

        let bucket = try store.createBucket(
            projectID: project.id,
            WorkspaceBucketDraft(
                name: "May sprint",
                hourlyRateMinorUnits: 9_000
            ),
            occurredAt: date
        )

        let updatedProject = try #require(store.workspace.project(named: "Launch sprint"))
        #expect(bucket.name == "May sprint")
        #expect(bucket.status == .open)
        #expect(updatedProject.buckets.last?.id == bucket.id)
        #expect(updatedProject.buckets.last?.hourlyRateMinorUnits == 9_000)
        #expect(store.workspace.activity.last?.message == "May sprint bucket created")
    }

    @Test func inMemoryWorkspaceStoreUpdatesBucketNameAndDefaultRate() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000811")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000811")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Retainer",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "April",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0,
                            defaultHourlyRateMinorUnits: 8_000
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let date = Date.billbiDate(year: 2026, month: 4, day: 27)

        let bucket = try store.updateBucket(
            projectID: projectID,
            bucketID: bucketID,
            WorkspaceBucketDraft(
                name: "  May  ",
                hourlyRateMinorUnits: 9_000
            ),
            occurredAt: date
        )

        #expect(bucket.name == "May")
        #expect(bucket.defaultHourlyRateMinorUnits == 9_000)
        #expect(store.workspace.projects.first?.buckets.first?.name == "May")
        #expect(store.workspace.projects.first?.buckets.first?.defaultHourlyRateMinorUnits == 9_000)
        #expect(store.workspace.activity.last?.message == "May bucket updated")
        #expect(store.workspace.activity.last?.occurredAt == date)
    }

    @Test func inMemoryWorkspaceStoreAddsTimeEntryToOpenBucket() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000801")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000801")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Entry capture",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Open workbench",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let date = Date.billbiDate(year: 2026, month: 4, day: 27)

        try store.addTimeEntry(
            projectID: projectID,
            bucketID: bucketID,
            draft: WorkspaceTimeEntryDraft(
                date: date,
                timeInput: "10:00-12:00",
                description: "Polish bucket table",
                isBillable: true
            ),
            occurredAt: date
        )

        let bucket = try #require(store.workspace.projects.first?.buckets.first)
        let entry = try #require(bucket.timeEntries.first)
        #expect(entry.date == date)
        #expect(entry.timeRangeLabel == "10:00-12:00")
        #expect(entry.durationMinutes == 120)
        #expect(entry.description == "Polish bucket table")
        #expect(bucket.effectiveBillableMinutes == 120)
        #expect(store.workspace.activity.map(\.message) == ["Open workbench entry added"])
    }

    @Test func addingTimeEntryToReadyBucketReopensItForReview() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000802")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000802")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Ready edits",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready workbench",
                            status: .ready,
                            totalMinorUnits: 20_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))

        try store.addTimeEntry(
            projectID: projectID,
            bucketID: bucketID,
            draft: WorkspaceTimeEntryDraft(
                date: Date.billbiDate(year: 2026, month: 4, day: 27),
                timeInput: "1h",
                description: "Late polish",
                isBillable: true
            )
        )

        let bucket = try #require(store.workspace.projects.first?.buckets.first)
        #expect(bucket.status == .open)
        #expect(bucket.timeEntries.map(\.description) == [
            "Billable time",
            "Late polish",
        ])
    }

    @Test func inMemoryWorkspaceStoreAddsFixedCostAndReopensReadyBucket() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000803")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000803")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Cost capture",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready with costs",
                            status: .ready,
                            totalMinorUnits: 20_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let date = Date.billbiDate(year: 2026, month: 4, day: 27)

        try store.addFixedCost(
            projectID: projectID,
            bucketID: bucketID,
            draft: WorkspaceFixedCostDraft(
                date: date,
                description: "Prototype hosting",
                amountMinorUnits: 5_000
            ),
            occurredAt: date
        )

        let bucket = try #require(store.workspace.projects.first?.buckets.first)
        #expect(bucket.status == .open)
        #expect(bucket.fixedCostEntries.map(\.description) == ["Prototype hosting"])
        #expect(bucket.effectiveFixedCostMinorUnits == 5_000)
        #expect(bucket.effectiveTotalMinorUnits == 25_000)
        #expect(store.workspace.activity.map(\.message) == ["Ready with costs cost added"])
    }

    @Test func deletingTimeEntryRemovesItFromOpenBucketTotals() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000804")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000804")!
        let keptEntryID = UUID(uuidString: "50000000-0000-0000-0000-000000000804")!
        let deletedEntryID = UUID(uuidString: "50000000-0000-0000-0000-000000000805")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Delete rows",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Open workbench",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: keptEntryID,
                                    date: Date.billbiDate(year: 2026, month: 4, day: 27),
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Kept polish",
                                    hourlyRateMinorUnits: 10_000
                                ),
                                WorkspaceTimeEntry(
                                    id: deletedEntryID,
                                    date: Date.billbiDate(year: 2026, month: 4, day: 27),
                                    startTime: "10:00",
                                    endTime: "12:00",
                                    durationMinutes: 120,
                                    description: "Removed polish",
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))

        try store.deleteEntry(
            projectID: projectID,
            bucketID: bucketID,
            rowID: deletedEntryID,
            kind: .time,
            isBillable: true,
            occurredAt: Date.billbiDate(year: 2026, month: 4, day: 27)
        )

        let bucket = try #require(store.workspace.projects.first?.buckets.first)
        #expect(bucket.timeEntries.map(\.id) == [keptEntryID])
        #expect(bucket.effectiveBillableMinutes == 60)
        #expect(bucket.effectiveTotalMinorUnits == 10_000)
        #expect(store.workspace.activity.map(\.message) == ["Open workbench entry deleted"])
    }

    @Test func deletingFixedCostEntryRemovesItFromReadyBucketAndReopensIt() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000805")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000805")!
        let deletedEntryID = UUID(uuidString: "60000000-0000-0000-0000-000000000805")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Delete costs",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready workbench",
                            status: .ready,
                            totalMinorUnits: 20_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            fixedCostEntries: [
                                WorkspaceFixedCostEntry(
                                    id: deletedEntryID,
                                    date: Date.billbiDate(year: 2026, month: 4, day: 27),
                                    description: "Prototype hosting",
                                    amountMinorUnits: 5_000
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))

        try store.deleteEntry(
            projectID: projectID,
            bucketID: bucketID,
            rowID: deletedEntryID,
            kind: .fixedCost,
            isBillable: true,
            occurredAt: Date.billbiDate(year: 2026, month: 4, day: 27)
        )

        let bucket = try #require(store.workspace.projects.first?.buckets.first)
        #expect(bucket.status == .open)
        #expect(bucket.fixedCostEntries.isEmpty)
        #expect(bucket.effectiveFixedCostMinorUnits == 0)
        #expect(bucket.effectiveTotalMinorUnits == 0)
        #expect(store.workspace.activity.map(\.message) == ["Ready workbench entry deleted"])
    }

    @Test func inMemoryWorkspaceStoreUpdatesEntryDatesAndReopensReadyBucket() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000806")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000806")!
        let timeEntryID = UUID(uuidString: "50000000-0000-0000-0000-000000000806")!
        let fixedCostID = UUID(uuidString: "60000000-0000-0000-0000-000000000806")!
        let originalDate = Date.billbiDate(year: 2026, month: 4, day: 27)
        let timeDate = Date.billbiDate(year: 2026, month: 5, day: 3)
        let fixedCostDate = Date.billbiDate(year: 2026, month: 5, day: 4)
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Move rows",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready workbench",
                            status: .ready,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: timeEntryID,
                                    date: originalDate,
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Existing time",
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ],
                            fixedCostEntries: [
                                WorkspaceFixedCostEntry(
                                    id: fixedCostID,
                                    date: originalDate,
                                    description: "Existing cost",
                                    amountMinorUnits: 2_500
                                ),
                            ]
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))

        try store.updateEntryDate(
            projectID: projectID,
            bucketID: bucketID,
            rowID: timeEntryID,
            kind: .time,
            date: timeDate
        )
        try store.updateEntryDate(
            projectID: projectID,
            bucketID: bucketID,
            rowID: fixedCostID,
            kind: .fixedCost,
            date: fixedCostDate
        )

        let bucket = try #require(store.workspace.projects.first?.buckets.first)
        #expect(bucket.status == .open)
        #expect(bucket.timeEntries.first?.date == timeDate)
        #expect(bucket.fixedCostEntries.first?.date == fixedCostDate)
        #expect(bucket.timeEntries.first?.description == "Existing time")
        #expect(bucket.fixedCostEntries.first?.amountMinorUnits == 2_500)
    }

    @Test func inMemoryWorkspaceStoreRejectsLockedAndUnknownEntryDateUpdates() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000807")!
        let lockedBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000807")!
        let openBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000808")!
        let timeEntryID = UUID(uuidString: "50000000-0000-0000-0000-000000000807")!
        let targetDate = Date.billbiDate(year: 2026, month: 5, day: 5)
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Locked rows",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: lockedBucketID,
                            name: "Finalized workbench",
                            status: .finalized,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0,
                            timeEntries: [
                                WorkspaceTimeEntry(
                                    id: timeEntryID,
                                    date: Date.billbiDate(year: 2026, month: 4, day: 27),
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Locked time",
                                    hourlyRateMinorUnits: 10_000
                                ),
                            ]
                        ),
                        WorkspaceBucket(
                            id: openBucketID,
                            name: "Open workbench",
                            status: .open,
                            totalMinorUnits: 0,
                            billableMinutes: 0,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        ))

        #expect(throws: WorkspaceStoreError.bucketLocked(.finalized)) {
            try store.updateEntryDate(
                projectID: projectID,
                bucketID: lockedBucketID,
                rowID: timeEntryID,
                kind: .time,
                date: targetDate
            )
        }
        #expect(throws: WorkspaceStoreError.entryNotFound) {
            try store.updateEntryDate(
                projectID: projectID,
                bucketID: openBucketID,
                rowID: UUID(uuidString: "50000000-0000-0000-0000-000000000808")!,
                kind: .time,
                date: targetDate
            )
        }

        let lockedBucket = try #require(store.workspace.projects.first?.buckets.first)
        #expect(lockedBucket.timeEntries.first?.date == Date.billbiDate(year: 2026, month: 4, day: 27))
    }

}
