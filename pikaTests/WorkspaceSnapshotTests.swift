import Foundation
import SwiftData
import Testing
@testable import pika

struct WorkspaceSnapshotTests {
    private func makePersistentModelContext() throws -> (ModelContext, URL) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pika-workspace-\(UUID().uuidString)")
            .appendingPathComponent("workspace.store")
        let container = try WorkspaceStore.makeModelContainer(inMemory: false, storeURL: storeURL)
        return (ModelContext(container), storeURL)
    }

    @Test func sampleWorkspaceComputesDashboardSummaryFromSeedData() {
        let workspace = WorkspaceFixtures.demoWorkspace
        let summary = workspace.dashboardSummary(on: WorkspaceFixtures.today)

        #expect(summary.outstandingMinorUnits == 245_000)
        #expect(summary.overdueMinorUnits == 125_000)
        #expect(summary.readyToInvoiceMinorUnits == 407_500)
        #expect(summary.thisMonthMinorUnits == 0)
        #expect(summary.needsAttention.map(\.title) == [
            "Acme Studio invoice overdue",
            "Northstar Labs mobile qa ready to invoice",
            "Happ.ines launch sprint ready to invoice",
        ])
        #expect(summary.needsAttention.map(\.target).count == 3)
        #expect(summary.needsAttention.first?.target == .invoice(UUID(uuidString: "40000000-0000-0000-0000-000000000002")!))
    }

    @Test func dashboardRevenueHistoryOnlyIncludesPaidInvoices() {
        let workspace = WorkspaceFixtures.demoWorkspace
        let summary = workspace.dashboardSummary(on: WorkspaceFixtures.today)

        #expect(summary.revenueHistory.isEmpty)
        #expect(summary.thisMonthMinorUnits == 0)
    }

    @Test func dashboardRevenueHistoryReflectsPaidInvoicesByIssueMonth() {
        var workspace = WorkspaceFixtures.demoWorkspace
        let projectIndex = workspace.projects.firstIndex { $0.name == "Launch sprint" }!

        workspace.projects[projectIndex].invoices.append(
            WorkspaceInvoice(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000901")!,
                number: "EHX-2026-901",
                clientName: "Happ.ines",
                projectName: "Launch sprint",
                bucketName: "April sprint",
                issueDate: Date.pikaDate(year: 2026, month: 4, day: 26),
                dueDate: Date.pikaDate(year: 2026, month: 5, day: 12),
                status: .finalized,
                totalMinorUnits: 80_000
            )
        )
        workspace.projects[projectIndex].invoices.append(
            WorkspaceInvoice(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000902")!,
                number: "EHX-2026-902",
                clientName: "Happ.ines",
                projectName: "Launch sprint",
                bucketName: "April sprint",
                issueDate: Date.pikaDate(year: 2026, month: 4, day: 26),
                dueDate: Date.pikaDate(year: 2026, month: 5, day: 12),
                status: .paid,
                totalMinorUnits: 95_000
            )
        )

        let summary = workspace.dashboardSummary(on: WorkspaceFixtures.today)

        #expect(summary.revenueHistory.map(\.label) == ["EHX-2026-902"])
        #expect(summary.revenueHistory.map(\.amountMinorUnits) == [95_000])
        #expect(summary.thisMonthMinorUnits == 95_000)
    }

    @Test func dashboardRevenueRangeSevenDaysUsesDailyBucketsEndingOnCurrentDate() {
        let points = [
            RevenuePoint(date: Date.pikaDate(year: 2026, month: 3, day: 16), label: "March", amountMinorUnits: 125_000),
            RevenuePoint(date: Date.pikaDate(year: 2026, month: 4, day: 23), label: "April first", amountMinorUnits: 80_000),
            RevenuePoint(date: Date.pikaDate(year: 2026, month: 4, day: 26), label: "April second", amountMinorUnits: 120_000),
        ]

        let visiblePoints = DashboardRevenueRange.sevenDays.visiblePoints(
            from: points,
            endingAt: WorkspaceFixtures.today
        )

        #expect(visiblePoints.map(\.label) == [
            "Apr 21",
            "Apr 22",
            "Apr 23",
            "Apr 24",
            "Apr 25",
            "Apr 26",
            "Apr 27",
        ])
        #expect(visiblePoints.map(\.amountMinorUnits) == [
            0,
            0,
            80_000,
            0,
            0,
            120_000,
            0,
        ])
    }

    @Test func dashboardRevenueRangeAllGroupsEveryInvoiceMonth() {
        let points = [
            RevenuePoint(date: Date.pikaDate(year: 2026, month: 3, day: 16), label: "March", amountMinorUnits: 125_000),
            RevenuePoint(date: Date.pikaDate(year: 2026, month: 4, day: 23), label: "April first", amountMinorUnits: 80_000),
            RevenuePoint(date: Date.pikaDate(year: 2026, month: 4, day: 26), label: "April second", amountMinorUnits: 120_000),
        ]

        let visiblePoints = DashboardRevenueRange.all.visiblePoints(
            from: points,
            endingAt: WorkspaceFixtures.today
        )

        #expect(DashboardRevenueRange.all.rawValue == "All")
        #expect(visiblePoints.map(\.label) == ["Mar 26", "Apr 26"])
        #expect(visiblePoints.map(\.amountMinorUnits) == [125_000, 200_000])
        #expect(DashboardRevenueRange.allCases.last == .all)
    }

    @Test func sampleWorkspaceExposesProjectCountsForProjectsSurface() throws {
        let workspace = WorkspaceFixtures.demoWorkspace

        #expect(workspace.activeProjects.map(\.name) == [
            "Launch sprint",
            "Mobile QA",
        ])
        #expect(workspace.archivedProjects.map(\.name) == [
            "Brand refresh",
        ])

        let launchSprint = try #require(workspace.project(named: "Launch sprint"))
        #expect(launchSprint.bucketCount == 3)
        #expect(launchSprint.readyBucketCount == 1)
        #expect(launchSprint.overdueInvoiceCount(on: WorkspaceFixtures.today) == 0)
        #expect(launchSprint.readyToInvoiceMinorUnits == 250_000)

        let brandRefresh = try #require(workspace.project(named: "Brand refresh"))
        #expect(brandRefresh.overdueInvoiceCount(on: WorkspaceFixtures.today) == 1)
    }

    @Test func sampleWorkspaceStoreProvidesBusinessProfileForSettings() {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let workspace = store.workspace

        #expect(workspace.businessProfile.businessName == WorkspaceFixtures.demoBusinessProfile.businessName)
        #expect(workspace.businessProfile.invoicePrefix == "EHX")
        #expect(workspace.businessProfile.nextInvoiceNumber == 5)
        #expect(workspace.businessProfile.currencyCode == "EUR")
        #expect(workspace.clients.map(\.name) == [
            "Happ.ines",
            "Northstar Labs",
            "Acme Studio",
        ])
    }

    @Test func bikeparkWorkspaceSeedContainsRealProjectAndWorklog() throws {
        let workspace = WorkspaceFixtures.bikeparkWorkspace
        let project = try #require(workspace.project(named: "Play Bikepark"))
        let bucket = try #require(project.buckets.first)

        #expect(workspace.businessProfile.businessName == "ehrax.dev")
        #expect(workspace.businessProfile.taxIdentifier == "151/260/41486")
        #expect(workspace.businessProfile.economicIdentifier == "DE320253387")
        #expect(workspace.clients.map(\.name) == ["Verein Bikepark Thunersee"])
        #expect(workspace.clients.first?.billingAddress == "Untere Ttüelmatt 4\n3624 Goldiwil\nSchweiz")
        #expect(bucket.name == "Trailpass Launch")
        #expect(bucket.status == .ready)
        #expect(bucket.timeEntries.count == 31)
        #expect(bucket.effectiveBillableMinutes == 4_440)
        #expect(bucket.effectiveTotalMinorUnits == 370_000)
        #expect(bucket.timeEntries.first?.date == Date.pikaDate(year: 2026, month: 3, day: 2))
        #expect(bucket.timeEntries.first?.description == "Initial MVP scaffold and webhook pipeline")
        #expect(bucket.timeEntries.map(\.date).contains(Date.pikaDate(year: 2036, month: 3, day: 26)) == false)
        #expect(bucket.timeEntries.map(\.date).contains(Date.pikaDate(year: 2026, month: 3, day: 26)))
    }

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
            "Fixed costs",
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
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [],
            activity: []
        ))
        let date = Date.pikaDate(year: 2026, month: 4, day: 27)

        let project = try store.createProject(
            WorkspaceProjectDraft(
                name: "Client portal",
                clientName: "Happ.ines",
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
                                    date: Date.pikaDate(year: 2026, month: 4, day: 27),
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
        let archiveDate = Date.pikaDate(year: 2026, month: 4, day: 27)
        let restoreDate = Date.pikaDate(year: 2026, month: 4, day: 28)

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
        let removeDate = Date.pikaDate(year: 2026, month: 4, day: 29)

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
        let archiveDate = Date.pikaDate(year: 2026, month: 4, day: 27)
        let restoreDate = Date.pikaDate(year: 2026, month: 4, day: 28)

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
        let removeDate = Date.pikaDate(year: 2026, month: 4, day: 29)

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
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000861")!
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000861")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000861")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: projectID,
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
                            issueDate: Date.pikaDate(year: 2026, month: 4, day: 1),
                            dueDate: Date.pikaDate(year: 2026, month: 4, day: 15),
                            status: .finalized,
                            totalMinorUnits: 12_000
                        ),
                    ]
                ),
            ],
            activity: []
        ))
        let occurredAt = Date.pikaDate(year: 2026, month: 4, day: 27)

        let project = try store.updateProject(
            projectID: projectID,
            WorkspaceProjectUpdateDraft(
                name: "  Retainer work  ",
                clientName: "  Northstar Labs  ",
                currencyCode: " usd "
            ),
            occurredAt: occurredAt
        )

        #expect(project.id == projectID)
        #expect(project.name == "Retainer work")
        #expect(project.clientName == "Northstar Labs")
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
        let date = Date.pikaDate(year: 2026, month: 4, day: 27)

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
            ],
            projects: [
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000811")!,
                    name: "Matching project",
                    clientName: "Original Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000812")!,
                    name: "Other project",
                    clientName: "Other Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: []
                ),
            ],
            activity: []
        ))
        let occurredAt = Date.pikaDate(year: 2026, month: 4, day: 27)

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
            "Other Client",
        ])
        #expect(store.workspace.activity.map(\.message) == ["Renamed Client client updated"])
        #expect(store.workspace.activity.first?.detail == "billing@renamed.example")
        #expect(store.workspace.activity.first?.occurredAt == occurredAt)
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

    @Test func persistentWorkspaceStoreLoadsSavedWorkspaceOnRelaunch() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }

        let initialStore = WorkspaceStore(
            seed: WorkspaceSnapshot(
                businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
                clients: [],
                projects: [],
                activity: []
            ),
            modelContext: modelContext
        )

        let client = try initialStore.createClient(WorkspaceClientDraft(
            name: "Persistent Client",
            email: "billing@persistent.example",
            billingAddress: "2 Saved Lane",
            defaultTermsDays: 21
        ))

        let relaunchedStore = WorkspaceStore(
            seed: WorkspaceFixtures.demoWorkspace,
            modelContext: modelContext
        )

        #expect(relaunchedStore.workspace.clients.map(\.id) == [client.id])
        #expect(relaunchedStore.workspace.clients.first?.name == "Persistent Client")
        #expect(relaunchedStore.workspace.activity.map(\.message) == ["Persistent Client client created"])
    }

    @Test func persistentWorkspaceStoreUpdatesBusinessProfileAndInvoiceDefaults() throws {
        let (modelContext, storeURL) = try makePersistentModelContext()
        defer {
            try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
        }
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000901")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000901")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 4)
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
        #expect(store.workspace.businessProfile.defaultTermsDays == 21)
        #expect(draft.invoiceNumber == "NCS-2026-042")
        #expect(draft.template == .kleinunternehmerClassic)
        #expect(draft.dueDate == Date.pikaDate(year: 2026, month: 5, day: 25))
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

    @Test func inMemoryWorkspaceStoreCreatesBucketWithRateDefaults() throws {
        let store = WorkspaceStore(seed: WorkspaceFixtures.demoWorkspace)
        let project = try #require(store.workspace.project(named: "Launch sprint"))
        let date = Date.pikaDate(year: 2026, month: 4, day: 27)

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
        let date = Date.pikaDate(year: 2026, month: 4, day: 27)

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
        let date = Date.pikaDate(year: 2026, month: 4, day: 27)

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
                date: Date.pikaDate(year: 2026, month: 4, day: 27),
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
        let date = Date.pikaDate(year: 2026, month: 4, day: 27)

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
                                    date: Date.pikaDate(year: 2026, month: 4, day: 27),
                                    startTime: "09:00",
                                    endTime: "10:00",
                                    durationMinutes: 60,
                                    description: "Kept polish",
                                    hourlyRateMinorUnits: 10_000
                                ),
                                WorkspaceTimeEntry(
                                    id: deletedEntryID,
                                    date: Date.pikaDate(year: 2026, month: 4, day: 27),
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
            occurredAt: Date.pikaDate(year: 2026, month: 4, day: 27)
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
                                    date: Date.pikaDate(year: 2026, month: 4, day: 27),
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
            occurredAt: Date.pikaDate(year: 2026, month: 4, day: 27)
        )

        let bucket = try #require(store.workspace.projects.first?.buckets.first)
        #expect(bucket.status == .open)
        #expect(bucket.fixedCostEntries.isEmpty)
        #expect(bucket.effectiveFixedCostMinorUnits == 0)
        #expect(bucket.effectiveTotalMinorUnits == 0)
        #expect(store.workspace.activity.map(\.message) == ["Ready workbench entry deleted"])
    }

    @Test func sampleWorkspaceExposesRecentActivityNewestFirst() {
        var workspace = WorkspaceFixtures.demoWorkspace
        workspace.activity = [
            WorkspaceActivity(message: "Older bucket marked ready", detail: "Launch sprint", occurredAt: Date(timeIntervalSince1970: 86_400)),
            WorkspaceActivity(message: "Newest invoice finalized", detail: "Northstar Labs", occurredAt: Date(timeIntervalSince1970: 259_200)),
            WorkspaceActivity(message: "Middle entry logged", detail: "Mobile QA", occurredAt: Date(timeIntervalSince1970: 172_800)),
        ]

        #expect(workspace.recentActivity.map(\.message) == [
            "Newest invoice finalized",
            "Middle entry logged",
            "Older bucket marked ready",
        ])
    }

    @Test func dashboardAttentionItemIDsStayUniqueWhenTitlesRepeat() throws {
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000011")!
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000011")!
        let repeatedTitleWorkspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000011")!,
                    name: "Launch sprint",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "May sprint",
                            status: .ready,
                            totalMinorUnits: 50_000,
                            billableMinutes: 240,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000012")!,
                    name: "Launch sprint",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: UUID(uuidString: "30000000-0000-0000-0000-000000000012")!,
                            name: "June sprint",
                            status: .ready,
                            totalMinorUnits: 60_000,
                            billableMinutes: 300,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: [
                        WorkspaceInvoice(
                            id: invoiceID,
                            number: "EHX-2026-101",
                            clientName: "Happ.ines",
                            issueDate: Date(timeIntervalSince1970: 0),
                            dueDate: Date(timeIntervalSince1970: 86_400),
                            status: .sent,
                            totalMinorUnits: 70_000
                        ),
                    ]
                ),
            ],
            activity: []
        )

        let firstSummary = repeatedTitleWorkspace.dashboardSummary(on: Date(timeIntervalSince1970: 172_800))
        let secondSummary = repeatedTitleWorkspace.dashboardSummary(on: Date(timeIntervalSince1970: 172_800))
        let ids = firstSummary.needsAttention.map(\.id)

        #expect(Set(ids).count == ids.count)
        #expect(ids == secondSummary.needsAttention.map(\.id))
        #expect(ids.contains("ready-bucket-\(bucketID.uuidString)"))
        #expect(ids.contains("overdue-invoice-\(invoiceID.uuidString)"))
        #expect(firstSummary.needsAttention.map(\.target).contains(.bucket(
            projectID: UUID(uuidString: "20000000-0000-0000-0000-000000000011")!,
            bucketID: bucketID
        )))
        #expect(firstSummary.needsAttention.map(\.target).contains(.invoice(invoiceID)))
    }

    @Test func projectOverdueCountsUseTheSuppliedDate() throws {
        let project = WorkspaceProject(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000021")!,
            name: "Date sensitive",
            clientName: "Happ.ines",
            currencyCode: "EUR",
            isArchived: false,
            buckets: [],
            invoices: [
                WorkspaceInvoice(
                    id: UUID(uuidString: "40000000-0000-0000-0000-000000000021")!,
                    number: "EHX-2026-201",
                    clientName: "Happ.ines",
                    issueDate: Date(timeIntervalSince1970: 0),
                    dueDate: Date(timeIntervalSince1970: 86_400),
                    status: .sent,
                    totalMinorUnits: 25_000
                ),
            ]
        )

        #expect(project.overdueInvoiceCount(on: Date(timeIntervalSince1970: 43_200)) == 0)
        #expect(project.overdueInvoiceCount(on: Date(timeIntervalSince1970: 172_800)) == 1)
    }

    @Test func projectCardsSelectTheMatchingProjectShellDestination() throws {
        let project = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Launch sprint"))

        #expect(PikaShellDestination.projectDestination(for: project) == .project(project.id))
    }

    @Test func projectDetailProjectionSelectsDefaultBucketAndFormatsRows() throws {
        let project = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Launch sprint"))
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(project.detailProjection(formatter: formatter))

        #expect(projection.selectedBucket.id == project.buckets[0].id)
        #expect(projection.bucketRows.map(\.name) == [
            "April sprint",
            "Discovery notes",
            "Internal planning",
        ])
        #expect(projection.bucketRows[0].meta == "10h · EUR 2,500.00 · EUR 500.00 fixed")
        #expect(projection.bucketRows[0].statusTitle == "Ready")
        #expect(projection.bucketRows[1].statusTitle == nil)
    }

    @Test func projectDetailProjectionMirrorsLinkedInvoiceStatusInBucketRows() throws {
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001201")!
        let project = WorkspaceProject(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000001201")!,
            name: "Invoice workflow",
            clientName: "Happ.ines",
            currencyCode: "EUR",
            isArchived: false,
            buckets: [
                WorkspaceBucket(
                    id: bucketID,
                    name: "Paid bucket",
                    status: .finalized,
                    totalMinorUnits: 20_000,
                    billableMinutes: 60,
                    fixedCostMinorUnits: 0
                ),
            ],
            invoices: [
                WorkspaceInvoice(
                    id: UUID(uuidString: "40000000-0000-0000-0000-000000001201")!,
                    number: "EHX-2026-1201",
                    clientName: "Happ.ines",
                    projectName: "Invoice workflow",
                    bucketName: "Paid bucket",
                    issueDate: Date.pikaDate(year: 2026, month: 4, day: 1),
                    dueDate: Date.pikaDate(year: 2026, month: 4, day: 15),
                    status: .paid,
                    totalMinorUnits: 20_000
                ),
            ]
        )
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(project.detailProjection(formatter: formatter))

        #expect(projection.bucketRows.first?.statusTitle == "Paid")
    }

    @Test func projectNormalizesUnknownBucketSelectionToFirstBucket() throws {
        let launchSprint = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Launch sprint"))
        let mobileQA = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Mobile QA"))

        #expect(launchSprint.normalizedBucketID(mobileQA.buckets[0].id) == launchSprint.buckets[0].id)
        #expect(launchSprint.normalizedBucketID(launchSprint.buckets[1].id) == launchSprint.buckets[1].id)
    }

    @Test func bucketDetailProjectionSummarizesBillableNonBillableAndFixedCosts() throws {
        let project = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Launch sprint"))
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(project.detailProjection(formatter: formatter))

        #expect(projection.title == "April sprint")
        #expect(projection.projectName == "Launch sprint")
        #expect(projection.clientName == "Happ.ines")
        #expect(projection.totalLabel == "EUR 2,500.00")
        #expect(projection.billableSummary == "10h billable")
        #expect(projection.nonBillableSummary == "0.5h non-billable")
        #expect(projection.fixedCostLabel == "EUR 500.00 fixed")
        #expect(projection.lineItems.map(\.description) == [
            "April sprint",
            "Prototype hosting",
        ])
    }

    @Test func bucketDetailProjectionUsesRowLevelEntriesWhenPresent() throws {
        let project = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Launch sprint"))
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(project.detailProjection(formatter: formatter))

        #expect(projection.entryRows.map(\.description) == [
            "API spec and auth token rotation",
            "Bookings list endpoint",
            "Review session with Adi",
            "Map tiles and clustering",
            "Standup and handoff notes",
            "Prototype hosting",
        ])
        #expect(projection.entryRows.map(\.dateLabel) == [
            "Apr 23",
            "Apr 23",
            "Apr 24",
            "Apr 24",
            "Apr 26",
            "Apr 26",
        ])
        #expect(projection.entryRows.map(\.timeLabel) == [
            "09:00-12:30",
            "13:30-17:00",
            "10:00-12:00",
            "14:00-15:00",
            "14:30-15:00",
            "Fixed cost",
        ])
        #expect(projection.entryRows.map(\.hoursLabel) == [
            "3.50",
            "3.50",
            "2.00",
            "1.00",
            "0.50",
            "-",
        ])
        #expect(projection.entryRows.map(\.amountLabel) == [
            "EUR 700.00",
            "EUR 700.00",
            "EUR 400.00",
            "EUR 200.00",
            "n/b",
            "EUR 500.00",
        ])
        #expect(projection.entryRows[4].isBillable == false)
        #expect(projection.entryRows[5].kind == .fixedCost)
    }

    @Test func inlineEntryDurationParserAcceptsRangesAndDurations() throws {
        #expect(WorkspaceEntryDurationParser.minutes(from: "10:00-12:30") == 150)
        #expect(WorkspaceEntryDurationParser.minutes(from: "10-12") == 120)
        #expect(WorkspaceEntryDurationParser.minutes(from: "2h") == 120)
        #expect(WorkspaceEntryDurationParser.minutes(from: "1.5h") == 90)
        #expect(WorkspaceEntryDurationParser.minutes(from: "90m") == 90)
        #expect(WorkspaceEntryDurationParser.minutes(from: "bad input") == nil)
    }

    @Test func inlineEntryDraftProjectionComputesDurationAndAmount() throws {
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let projection = WorkspaceInlineEntryDraftProjection(
            timeInput: "10:00-12:00",
            description: "Polish invoice handoff",
            isBillable: true,
            hourlyRateMinorUnits: 20_000,
            formatter: formatter
        )

        #expect(projection.durationMinutes == 120)
        #expect(projection.hoursLabel == "2.00")
        #expect(projection.amountLabel == "EUR 400.00")

        let nonBillableProjection = WorkspaceInlineEntryDraftProjection(
            timeInput: "30m",
            description: "Internal planning",
            isBillable: false,
            hourlyRateMinorUnits: 20_000,
            formatter: formatter
        )
        #expect(nonBillableProjection.amountLabel == "n/b")
    }

    @Test func invoicePreviewProjectionSelectsNewestInvoiceAndMarksOverdueRows() throws {
        let workspace = WorkspaceFixtures.demoWorkspace
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(workspace.invoicePreviewProjection(on: WorkspaceFixtures.today, formatter: formatter))

        #expect(projection.selectedInvoice.number == "EHX-2026-004")
        #expect(projection.rows.map(\.number) == [
            "EHX-2026-004",
            "EHX-2026-003",
        ])
        #expect(projection.rows[0].statusTitle == "Finalized")
        #expect(projection.rows[0].isOverdue == false)
        #expect(projection.rows[1].statusTitle == "Overdue")
        #expect(projection.rows[1].isOverdue == true)
        #expect(projection.rows[0].totalLabel == "EUR 1,200.00")
    }

    @Test func invoicePreviewProjectionIncludesRecipientAddressForPDFPreview() throws {
        let workspace = WorkspaceFixtures.demoWorkspace
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let projection = try #require(workspace.invoicePreviewProjection(on: WorkspaceFixtures.today, formatter: formatter))

        #expect(projection.rows[0].clientName == "Northstar Labs")
        #expect(projection.rows[0].billingAddress == "12 Polaris Yard, Berlin")
        #expect(projection.rows[1].clientName == "Acme Studio")
        #expect(projection.rows[1].billingAddress == "5 Market Street, Dublin")
    }

    @Test func invoicePreviewProjectionIncludesInvoiceSnapshotContextForPDFs() throws {
        let workspace = WorkspaceFixtures.demoWorkspace
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let projection = try #require(workspace.invoicePreviewProjection(on: WorkspaceFixtures.today, formatter: formatter))

        #expect(projection.rows[0].projectName == "Mobile QA")
        #expect(projection.rows[0].bucketName == "Regression pass")
        #expect(projection.rows[0].lineItems.map(\.description) == [
            "Regression pass QA",
        ])
        #expect(projection.rows[0].lineItems.map(\.quantityLabel) == [
            "8h",
        ])
        #expect(projection.rows[0].lineItems.map(\.quantityValueLabel) == [
            "8",
        ])
        #expect(projection.rows[0].lineItems.map(\.unitLabel) == [
            "Stunden",
        ])
        #expect(projection.rows[0].lineItems.map(\.unitPriceLabel) == [
            "EUR 150.00",
        ])
        #expect(projection.rows[0].lineItems.map(\.amountLabel) == [
            "EUR 1,200.00",
        ])
    }

    @Test func invoicePreviewProjectionUsesStableFallbackLineItemForLegacyInvoices() throws {
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000301")!
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: WorkspaceFixtures.demoWorkspace.clients,
            projects: [
                WorkspaceProject(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000301")!,
                    name: "Legacy invoice",
                    clientName: "Happ.ines",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [],
                    invoices: [
                        WorkspaceInvoice(
                            id: invoiceID,
                            number: "EHX-2026-301",
                            clientName: "Happ.ines",
                            issueDate: Date(timeIntervalSince1970: 0),
                            dueDate: Date(timeIntervalSince1970: 86_400),
                            status: .finalized,
                            totalMinorUnits: 42_000
                        ),
                    ]
                ),
            ],
            activity: []
        )
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let first = try #require(workspace.invoicePreviewProjection(on: WorkspaceFixtures.today, formatter: formatter))
        let second = try #require(workspace.invoicePreviewProjection(on: WorkspaceFixtures.today, formatter: formatter))

        #expect(first.rows[0].lineItems.first?.id == second.rows[0].lineItems.first?.id)
        #expect(first.rows[0].lineItems.first?.id == invoiceID)
        #expect(first.rows[0].lineItems.first?.description == "Services rendered")
        #expect(first.rows[0].lineItems.first?.amountLabel == "EUR 420.00")
    }

    @Test func projectOverviewSummaryTotalsActiveProjects() {
        let workspace = WorkspaceFixtures.demoWorkspace
        let summary = workspace.projectOverviewSummary(
            for: workspace.activeProjects,
            on: WorkspaceFixtures.today
        )

        #expect(summary.projectCount == 2)
        #expect(summary.openMinorUnits == 95_000)
        #expect(summary.readyMinorUnits == 407_500)
        #expect(summary.overdueMinorUnits == 0)
    }
}
