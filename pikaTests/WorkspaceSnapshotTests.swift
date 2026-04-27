import Foundation
import Testing
@testable import pika

struct WorkspaceSnapshotTests {
    @Test func sampleWorkspaceComputesDashboardSummaryFromSeedData() {
        let workspace = WorkspaceSnapshot.sample
        let summary = workspace.dashboardSummary(on: WorkspaceSnapshot.sampleToday)

        #expect(summary.outstandingMinorUnits == 245_000)
        #expect(summary.overdueMinorUnits == 125_000)
        #expect(summary.readyToInvoiceMinorUnits == 407_500)
        #expect(summary.thisMonthMinorUnits == 120_000)
        #expect(summary.needsAttention.map(\.title) == [
            "Acme Studio invoice overdue",
            "Northstar Labs mobile qa ready to invoice",
            "Happ.ines launch sprint ready to invoice",
        ])
    }

    @Test func dashboardRevenueHistoryMatchesTwelveMonthDesignWindow() {
        let workspace = WorkspaceSnapshot.sample
        let summary = workspace.dashboardSummary(on: WorkspaceSnapshot.sampleToday)

        #expect(summary.revenueHistory.map(\.label) == [
            "May 25",
            "Jun",
            "Jul",
            "Aug",
            "Sep",
            "Oct",
            "Nov",
            "Dec",
            "Jan",
            "Feb",
            "Mar",
            "Apr 26",
        ])
        #expect(summary.revenueHistory.map(\.amountMinorUnits).last == summary.thisMonthMinorUnits)
    }

    @Test func sampleWorkspaceExposesProjectCountsForProjectsSurface() throws {
        let workspace = WorkspaceSnapshot.sample

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
        #expect(launchSprint.overdueInvoiceCount(on: WorkspaceSnapshot.sampleToday) == 0)
        #expect(launchSprint.readyToInvoiceMinorUnits == 250_000)

        let brandRefresh = try #require(workspace.project(named: "Brand refresh"))
        #expect(brandRefresh.overdueInvoiceCount(on: WorkspaceSnapshot.sampleToday) == 1)
    }

    @Test func sampleWorkspaceStoreProvidesBusinessProfileForSettings() {
        let store = WorkspaceStore(seed: .sample)
        let workspace = store.workspace

        #expect(workspace.businessProfile.businessName == "Ehrax Studio")
        #expect(workspace.businessProfile.invoicePrefix == "EHX")
        #expect(workspace.businessProfile.nextInvoiceNumber == 5)
        #expect(workspace.businessProfile.currencyCode == "EUR")
        #expect(workspace.clients.map(\.name) == [
            "Happ.ines",
            "Northstar Labs",
            "Acme Studio",
        ])
    }

    @Test func inMemoryWorkspaceStoreMarksOpenInvoiceableBucketReadyAndRecordsActivity() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000000501")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000000501")!
        let store = WorkspaceStore(seed: WorkspaceSnapshot(
            businessProfile: WorkspaceSnapshot.sample.businessProfile,
            clients: WorkspaceSnapshot.sample.clients,
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
        var businessProfile = WorkspaceSnapshot.sample.businessProfile
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
                issueDate: issueDate,
                dueDate: dueDate,
                currencyCode: "EUR",
                note: "Thank you."
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
        #expect(storedInvoice.businessSnapshot?.businessName == "Ehrax Studio")
        #expect(storedInvoice.clientSnapshot?.billingAddress == "1 Snapshot Way")
        #expect(storedInvoice.projectName == "Snapshot Project")
        #expect(storedInvoice.bucketName == "Ready Snapshot")
        #expect(storedInvoice.currencyCode == "EUR")
        #expect(storedInvoice.note == "Thank you.")
        #expect(storedInvoice.lineItems.map(\.description) == [
            "Billable time",
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

    @Test func inMemoryWorkspaceStoreAppliesInvoiceStatusTransitionsAndRejectsInvalidOnes() throws {
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000701")!
        var workspace = WorkspaceSnapshot.sample
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

    @Test func sampleWorkspaceExposesRecentActivityNewestFirst() {
        var workspace = WorkspaceSnapshot.sample
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
            businessProfile: WorkspaceSnapshot.sample.businessProfile,
            clients: WorkspaceSnapshot.sample.clients,
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
        let project = try #require(WorkspaceSnapshot.sample.project(named: "Launch sprint"))

        #expect(PikaShellDestination.projectDestination(for: project) == .project(project.id))
    }

    @Test func projectDetailProjectionSelectsDefaultBucketAndFormatsRows() throws {
        let project = try #require(WorkspaceSnapshot.sample.project(named: "Launch sprint"))
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(project.detailProjection(formatter: formatter))

        #expect(projection.selectedBucket.id == project.buckets[0].id)
        #expect(projection.bucketRows.map(\.name) == [
            "April sprint",
            "Discovery notes",
            "Internal planning",
        ])
        #expect(projection.bucketRows[0].meta == "20h · EUR 2,500.00 · EUR 500.00 fixed")
        #expect(projection.bucketRows[0].statusTitle == "Ready")
        #expect(projection.bucketRows[1].statusTitle == nil)
    }

    @Test func projectNormalizesUnknownBucketSelectionToFirstBucket() throws {
        let launchSprint = try #require(WorkspaceSnapshot.sample.project(named: "Launch sprint"))
        let mobileQA = try #require(WorkspaceSnapshot.sample.project(named: "Mobile QA"))

        #expect(launchSprint.normalizedBucketID(mobileQA.buckets[0].id) == launchSprint.buckets[0].id)
        #expect(launchSprint.normalizedBucketID(launchSprint.buckets[1].id) == launchSprint.buckets[1].id)
    }

    @Test func bucketDetailProjectionSummarizesBillableNonBillableAndFixedCosts() throws {
        let project = try #require(WorkspaceSnapshot.sample.project(named: "Launch sprint"))
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(project.detailProjection(formatter: formatter))

        #expect(projection.title == "April sprint")
        #expect(projection.projectName == "Launch sprint")
        #expect(projection.clientName == "Happ.ines")
        #expect(projection.totalLabel == "EUR 2,500.00")
        #expect(projection.billableSummary == "20h billable")
        #expect(projection.nonBillableSummary == "0h non-billable")
        #expect(projection.fixedCostLabel == "EUR 500.00 fixed")
        #expect(projection.lineItems.map(\.description) == [
            "Billable time",
            "Fixed costs",
            "Non-billable time",
        ])
    }

    @Test func invoicePreviewProjectionSelectsNewestInvoiceAndMarksOverdueRows() throws {
        let workspace = WorkspaceSnapshot.sample
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(workspace.invoicePreviewProjection(on: WorkspaceSnapshot.sampleToday, formatter: formatter))

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
        let workspace = WorkspaceSnapshot.sample
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let projection = try #require(workspace.invoicePreviewProjection(on: WorkspaceSnapshot.sampleToday, formatter: formatter))

        #expect(projection.rows[0].clientName == "Northstar Labs")
        #expect(projection.rows[0].billingAddress == "12 Polaris Yard, Berlin")
        #expect(projection.rows[1].clientName == "Acme Studio")
        #expect(projection.rows[1].billingAddress == "5 Market Street, Dublin")
    }

    @Test func invoicePreviewProjectionIncludesInvoiceSnapshotContextForPDFs() throws {
        let workspace = WorkspaceSnapshot.sample
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let projection = try #require(workspace.invoicePreviewProjection(on: WorkspaceSnapshot.sampleToday, formatter: formatter))

        #expect(projection.rows[0].projectName == "Mobile QA")
        #expect(projection.rows[0].bucketName == "Regression pass")
        #expect(projection.rows[0].lineItems.map(\.description) == [
            "Regression pass QA",
        ])
        #expect(projection.rows[0].lineItems.map(\.quantityLabel) == [
            "8h",
        ])
        #expect(projection.rows[0].lineItems.map(\.amountLabel) == [
            "EUR 1,200.00",
        ])
    }

    @Test func invoicePreviewProjectionUsesStableFallbackLineItemForLegacyInvoices() throws {
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000000301")!
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceSnapshot.sample.businessProfile,
            clients: WorkspaceSnapshot.sample.clients,
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

        let first = try #require(workspace.invoicePreviewProjection(on: WorkspaceSnapshot.sampleToday, formatter: formatter))
        let second = try #require(workspace.invoicePreviewProjection(on: WorkspaceSnapshot.sampleToday, formatter: formatter))

        #expect(first.rows[0].lineItems.first?.id == second.rows[0].lineItems.first?.id)
        #expect(first.rows[0].lineItems.first?.id == invoiceID)
        #expect(first.rows[0].lineItems.first?.description == "Services rendered")
        #expect(first.rows[0].lineItems.first?.amountLabel == "EUR 420.00")
    }

    @Test func projectOverviewSummaryTotalsActiveProjects() {
        let workspace = WorkspaceSnapshot.sample
        let summary = workspace.projectOverviewSummary(
            for: workspace.activeProjects,
            on: WorkspaceSnapshot.sampleToday
        )

        #expect(summary.projectCount == 2)
        #expect(summary.openMinorUnits == 95_000)
        #expect(summary.readyMinorUnits == 407_500)
        #expect(summary.overdueMinorUnits == 0)
    }
}
