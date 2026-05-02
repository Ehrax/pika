import Foundation
import Testing
@testable import pika

struct WorkspaceInvoicingWorkflowTests {
    @Test func workflowFinalizesReadyBucketIntoInvoiceOutcome() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000001601")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001601")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001601")!
        let issueDate = Date.pikaDate(year: 2026, month: 5, day: 2)
        let dueDate = Date.pikaDate(year: 2026, month: 5, day: 16)

        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Workflow Client",
                    email: "billing@workflow.example",
                    billingAddress: "1 Workflow Way",
                    defaultTermsDays: 21
                ),
            ],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    clientID: clientID,
                    name: "Workflow Project",
                    clientName: "Workflow Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Workflow",
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
        )

        let result = try WorkspaceInvoicingWorkflow().finalizeInvoice(
            workspace: workspace,
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Workflow Client",
                recipientEmail: "billing@workflow.example",
                recipientBillingAddress: "1 Workflow Way",
                invoiceNumber: " EHX-2026-601 ",
                template: .kleinunternehmerClassic,
                issueDate: issueDate,
                dueDate: dueDate,
                servicePeriod: " May 2026 ",
                currencyCode: " eur ",
                taxNote: "Thanks."
            )
        )

        #expect(result.projectID == projectID)
        #expect(result.bucketID == bucketID)
        #expect(result.invoice.number == "EHX-2026-601")
        #expect(result.invoice.projectName == "Workflow Project")
        #expect(result.invoice.bucketName == "Ready Workflow")
        #expect(result.invoice.totalMinorUnits == 132_000)
        #expect(result.invoice.status == .finalized)
        #expect(result.invoice.servicePeriod == "May 2026")
        #expect(result.invoice.currencyCode == "EUR")
        #expect(result.invoice.note == "Thanks.")
        #expect(result.invoice.lineItems.map(\.description) == [
            "Ready Workflow",
            "Fixed costs",
        ])
    }

    @Test func workflowRejectsDuplicateInvoiceNumberFromWorkspaceSnapshot() {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001602")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001602")!
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Workflow Project",
                    clientName: "Workflow Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: bucketID,
                            name: "Ready Workflow",
                            status: .ready,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: [
                        WorkspaceInvoice(
                            id: UUID(uuidString: "40000000-0000-0000-0000-000000001602")!,
                            number: "ehx-2026-602",
                            clientName: "Workflow Client",
                            issueDate: Date.pikaDate(year: 2026, month: 5, day: 2),
                            dueDate: Date.pikaDate(year: 2026, month: 5, day: 16),
                            status: .finalized,
                            totalMinorUnits: 10_000
                        ),
                    ]
                ),
            ],
            activity: []
        )

        #expect(throws: WorkspaceInvoicingWorkflowError.duplicateInvoiceNumber) {
            try WorkspaceInvoicingWorkflow().finalizeInvoice(
                workspace: workspace,
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Workflow Client",
                    recipientEmail: "billing@workflow.example",
                    recipientBillingAddress: "1 Workflow Way",
                    invoiceNumber: " EHX-2026-602 ",
                    template: .kleinunternehmerClassic,
                    issueDate: Date.pikaDate(year: 2026, month: 5, day: 2),
                    dueDate: Date.pikaDate(year: 2026, month: 5, day: 16),
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                )
            )
        }
    }

    @Test func workflowRejectsNonReadyOrEmptyBuckets() {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001603")!
        let openBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001603")!
        let emptyBucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001604")!
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [],
            projects: [
                WorkspaceProject(
                    id: projectID,
                    name: "Workflow Project",
                    clientName: "Workflow Client",
                    currencyCode: "EUR",
                    isArchived: false,
                    buckets: [
                        WorkspaceBucket(
                            id: openBucketID,
                            name: "Open Bucket",
                            status: .open,
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0
                        ),
                        WorkspaceBucket(
                            id: emptyBucketID,
                            name: "Empty Ready Bucket",
                            status: .ready,
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
        let draft = InvoiceFinalizationDraft(
            recipientName: "Workflow Client",
            recipientEmail: "billing@workflow.example",
            recipientBillingAddress: "1 Workflow Way",
            invoiceNumber: "EHX-2026-603",
            template: .kleinunternehmerClassic,
            issueDate: Date.pikaDate(year: 2026, month: 5, day: 2),
            dueDate: Date.pikaDate(year: 2026, month: 5, day: 16),
            servicePeriod: "May 2026",
            currencyCode: "EUR",
            taxNote: ""
        )

        #expect(throws: WorkspaceInvoicingWorkflowError.bucketStatusNotReady(.open)) {
            try WorkspaceInvoicingWorkflow().finalizeInvoice(
                workspace: workspace,
                projectID: projectID,
                bucketID: openBucketID,
                draft: draft
            )
        }
        #expect(throws: WorkspaceInvoicingWorkflowError.bucketNotInvoiceable) {
            try WorkspaceInvoicingWorkflow().finalizeInvoice(
                workspace: workspace,
                projectID: projectID,
                bucketID: emptyBucketID,
                draft: draft
            )
        }
    }
}
