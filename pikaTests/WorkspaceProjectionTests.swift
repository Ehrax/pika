import Foundation
import Testing
@testable import pika

struct WorkspaceProjectionTests {
    @Test func dashboardSummaryProjectionMatchesWorkspaceSummaryBehavior() {
        let workspace = WorkspaceFixtures.demoWorkspace

        #expect(
            WorkspaceDashboardProjections.summary(for: workspace, on: WorkspaceFixtures.today) ==
                workspace.dashboardSummary(on: WorkspaceFixtures.today)
        )
    }

    @Test func projectBucketProjectionOwnerPreservesProjectDetailValues() throws {
        let launchSprint = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Launch sprint"))
        let mobileQA = try #require(WorkspaceFixtures.demoWorkspace.project(named: "Mobile QA"))
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        let projection = try #require(
            WorkspaceProjectBucketProjections.detail(
                for: launchSprint,
                formatter: formatter,
                on: WorkspaceFixtures.today
            )
        )

        #expect(projection.selectedBucket.id == launchSprint.buckets[0].id)
        #expect(projection.title == "April sprint")
        #expect(projection.projectName == "Launch sprint")
        #expect(projection.clientName == "Happ.ines")
        #expect(projection.currencyCode == "EUR")
        #expect(projection.totalLabel == "EUR 2,500.00")
        #expect(projection.bucketRows.map(\.name) == [
            "Discovery notes",
            "Internal planning",
            "April sprint",
        ])
        let aprilSprintRow = try #require(projection.bucketRows.first { $0.name == "April sprint" })
        let discoveryNotesRow = try #require(projection.bucketRows.first { $0.name == "Discovery notes" })
        #expect(aprilSprintRow.meta == "10h · EUR 2,500.00 · EUR 500.00 fixed")
        #expect(aprilSprintRow.statusTitle == "Ready")
        #expect(discoveryNotesRow.statusTitle == nil)
        #expect(projection.lineItems.map(\.description) == [
            "April sprint",
            "Prototype hosting",
        ])
        #expect(
            WorkspaceProjectBucketProjections.normalizedBucketID(
                for: launchSprint,
                selectedBucketID: mobileQA.buckets[0].id
            ) == launchSprint.normalizedBucketID(mobileQA.buckets[0].id)
        )
    }

    @Test func projectBucketRowsSortByWorkflowStateWithOpenBucketsMostRecentlyEdited() throws {
        let projectID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000009001"))
        let openOlderID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000009001"))
        let readyID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000009002"))
        let finalizedID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000009003"))
        let overdueID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000009004"))
        let paidID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000009005"))
        let openNewerID = try #require(UUID(uuidString: "30000000-0000-0000-0000-000000009006"))
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let project = WorkspaceProject(
            id: projectID,
            name: "Sorting",
            clientName: "Client",
            currencyCode: "EUR",
            isArchived: false,
            buckets: [
                bucket(id: paidID, name: "Paid", status: .finalized),
                bucket(id: overdueID, name: "Overdue", status: .finalized),
                bucket(id: finalizedID, name: "Finalized", status: .finalized),
                bucket(id: readyID, name: "Ready", status: .ready),
                bucket(id: openOlderID, name: "Open older", status: .open, updatedAt: Date.pikaDate(year: 2026, month: 4, day: 20)),
                bucket(id: openNewerID, name: "Open newer", status: .open, updatedAt: Date.pikaDate(year: 2026, month: 4, day: 24)),
            ],
            invoices: [
                invoice(id: 1, projectID: projectID, bucketID: finalizedID, bucketName: "Finalized", status: .sent, dueDate: Date.pikaDate(year: 2026, month: 5, day: 10)),
                invoice(id: 2, projectID: projectID, bucketID: overdueID, bucketName: "Overdue", status: .sent, dueDate: Date.pikaDate(year: 2026, month: 4, day: 1)),
                invoice(id: 3, projectID: projectID, bucketID: paidID, bucketName: "Paid", status: .paid, dueDate: Date.pikaDate(year: 2026, month: 4, day: 1)),
            ]
        )

        let projection = try #require(
            WorkspaceProjectBucketProjections.detail(
                for: project,
                formatter: formatter,
                on: WorkspaceFixtures.today
            )
        )

        #expect(projection.bucketRows.map(\.name) == [
            "Open newer",
            "Open older",
            "Ready",
            "Finalized",
            "Overdue",
            "Paid",
        ])
    }

    @Test func invoiceProjectionOwnerPreservesWorkspacePreviewBehavior() throws {
        let workspace = WorkspaceFixtures.demoWorkspace
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

        #expect(
            WorkspaceInvoiceProjections.preview(
                for: workspace,
                on: WorkspaceFixtures.today,
                formatter: formatter
            ) == workspace.invoicePreviewProjection(
                on: WorkspaceFixtures.today,
                formatter: formatter
            )
        )
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
        #expect(
            summary.needsAttention.first?.target ==
                .invoice(UUID(uuidString: "40000000-0000-0000-0000-000000000002")!)
        )
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
            RevenuePoint(
                date: Date.pikaDate(year: 2026, month: 4, day: 23),
                label: "April first",
                amountMinorUnits: 80_000
            ),
            RevenuePoint(
                date: Date.pikaDate(year: 2026, month: 4, day: 26),
                label: "April second",
                amountMinorUnits: 120_000
            ),
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
            RevenuePoint(
                date: Date.pikaDate(year: 2026, month: 4, day: 23),
                label: "April first",
                amountMinorUnits: 80_000
            ),
            RevenuePoint(
                date: Date.pikaDate(year: 2026, month: 4, day: 26),
                label: "April second",
                amountMinorUnits: 120_000
            ),
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

    @Test func sampleWorkspaceExposesRecentActivityNewestFirst() {
        var workspace = WorkspaceFixtures.demoWorkspace
        workspace.activity = [
            WorkspaceActivity(
                message: "Older bucket marked ready",
                detail: "Launch sprint",
                occurredAt: Date(timeIntervalSince1970: 86_400)
            ),
            WorkspaceActivity(
                message: "Newest invoice finalized",
                detail: "Northstar Labs",
                occurredAt: Date(timeIntervalSince1970: 259_200)
            ),
            WorkspaceActivity(
                message: "Middle entry logged",
                detail: "Mobile QA",
                occurredAt: Date(timeIntervalSince1970: 172_800)
            ),
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
            "Discovery notes",
            "Internal planning",
            "April sprint",
        ])
        let aprilSprintRow = try #require(projection.bucketRows.first { $0.name == "April sprint" })
        let discoveryNotesRow = try #require(projection.bucketRows.first { $0.name == "Discovery notes" })
        #expect(aprilSprintRow.meta == "10h · EUR 2,500.00 · EUR 500.00 fixed")
        #expect(aprilSprintRow.statusTitle == "Ready")
        #expect(discoveryNotesRow.statusTitle == nil)
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

        let projection = try #require(workspace.invoicePreviewProjection(
            on: WorkspaceFixtures.today,
            formatter: formatter
        ))

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
        let projection = try #require(workspace.invoicePreviewProjection(
            on: WorkspaceFixtures.today,
            formatter: formatter
        ))

        #expect(projection.rows[0].clientName == "Northstar Labs")
        #expect(projection.rows[0].billingAddress == "12 Polaris Yard, Berlin")
        #expect(projection.rows[1].clientName == "Acme Studio")
        #expect(projection.rows[1].billingAddress == "5 Market Street, Dublin")
    }

    @Test func invoicePreviewProjectionIncludesInvoiceSnapshotContextForPDFs() throws {
        let workspace = WorkspaceFixtures.demoWorkspace
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let projection = try #require(workspace.invoicePreviewProjection(
            on: WorkspaceFixtures.today,
            formatter: formatter
        ))

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

    @Test func projectionJoinsPreferStableIDsOverRenamedDisplayNames() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000009501")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000009501")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000009501")!
        let invoiceID = UUID(uuidString: "40000000-0000-0000-0000-000000009501")!
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Renamed Client",
                    email: "billing@client.example",
                    billingAddress: "42 Stable ID Way",
                    defaultTermsDays: 14
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Renamed Project",
                    clientName: "Renamed Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Renamed Bucket",
                            status: .finalized,
                            totalMinorUnits: 24_000,
                            billableMinutes: 120,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: [
                        WorkspaceInvoice(
                            id: invoiceID,
                            number: "EHX-2026-951",
                            clientID: clientID,
                            clientName: "Old Client Name",
                            projectID: projectID,
                            projectName: "Old Project Name",
                            bucketID: bucketID,
                            bucketName: "Old Bucket Name",
                            issueDate: Date.pikaDate(year: 2026, month: 4, day: 20),
                            dueDate: Date.pikaDate(year: 2026, month: 5, day: 4),
                            status: .finalized,
                            totalMinorUnits: 24_000
                        ),
                    ]
                ),
            ],
            activity: []
        )
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let project = try #require(workspace.projects.first)
        let detail = try #require(project.detailProjection(formatter: formatter, on: WorkspaceFixtures.today))
        let preview = try #require(workspace.invoicePreviewProjection(
            on: WorkspaceFixtures.today,
            formatter: formatter
        ))

        #expect(detail.bucketRows.first?.statusTitle == "Finalized")
        #expect(preview.rows.first?.clientName == "Old Client Name")
        #expect(preview.rows.first?.billingAddress == "42 Stable ID Way")
    }

    @Test func projectOverviewSummaryTotalsActiveProjects() {
        let workspace = WorkspaceFixtures.demoWorkspace
        let summary = WorkspaceProjectProjections.overviewSummary(
            for: workspace.activeProjects,
            on: WorkspaceFixtures.today
        )

        #expect(summary.projectCount == 2)
        #expect(summary.openMinorUnits == 95_000)
        #expect(summary.readyMinorUnits == 407_500)
        #expect(summary.overdueMinorUnits == 0)
    }
}

private func bucket(
    id: UUID,
    name: String,
    status: BucketStatus,
    updatedAt: Date? = nil
) -> WorkspaceBucket {
    WorkspaceBucket(
        id: id,
        name: name,
        status: status,
        updatedAt: updatedAt,
        totalMinorUnits: 10_000,
        billableMinutes: 60,
        fixedCostMinorUnits: 0
    )
}

private func invoice(
    id: Int,
    projectID: UUID,
    bucketID: UUID,
    bucketName: String,
    status: InvoiceStatus,
    dueDate: Date
) -> WorkspaceInvoice {
    WorkspaceInvoice(
        id: UUID(uuidString: String(format: "40000000-0000-0000-0000-000000009%03d", id))!,
        number: "INV-\(id)",
        clientName: "Client",
        projectID: projectID,
        projectName: "Sorting",
        bucketID: bucketID,
        bucketName: bucketName,
        issueDate: Date.pikaDate(year: 2026, month: 4, day: 1),
        dueDate: dueDate,
        status: status,
        totalMinorUnits: 10_000
    )
}
