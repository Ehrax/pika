import Foundation
import Testing
@testable import billbi

struct WorkspaceInvoicingWorkflowTests {
    @Test func workflowValidatesInvoiceStatusTransitions() throws {
        let workflow = WorkspaceInvoicingWorkflow()

        try workflow.ensureInvoiceStatusTransition(from: .finalized, to: .sent)
        try workflow.ensureInvoiceStatusTransition(from: .finalized, to: .paid)
        try workflow.ensureInvoiceStatusTransition(from: .finalized, to: .cancelled)
        try workflow.ensureInvoiceStatusTransition(from: .sent, to: .paid)
        try workflow.ensureInvoiceStatusTransition(from: .sent, to: .cancelled)

        #expect(throws: WorkspaceInvoicingWorkflowError.invalidInvoiceStatusTransition(from: .paid, to: .sent)) {
            try workflow.ensureInvoiceStatusTransition(from: .paid, to: .sent)
        }
    }

    @Test func workflowFinalizesReadyBucketIntoInvoiceOutcome() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000001601")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001601")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001601")!
        let issueDate = Date.billbiDate(year: 2026, month: 5, day: 2)
        let dueDate = Date.billbiDate(year: 2026, month: 5, day: 16)

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
            "Fixed Charges",
        ])
    }

    @Test func workflowSnapshotsSenderTaxLegalFieldsFromBusinessProfile() throws {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001699")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001699")!
        var profile = WorkspaceFixtures.demoWorkspace.businessProfile
        profile.senderTaxLegalFields = [
            WorkspaceTaxLegalField(label: "VAT ID", value: "DE123", placement: .senderDetails, sortOrder: 0),
            WorkspaceTaxLegalField(label: "Hidden", value: "SHOULD_NOT_RENDER", placement: .hidden, sortOrder: 1),
        ]
        let workspace = WorkspaceSnapshot(
            businessProfile: profile,
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
                invoiceNumber: "EHX-2026-699",
                template: .kleinunternehmerClassic,
                issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
                dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: ""
            )
        )

        #expect(result.invoice.businessSnapshot?.senderTaxLegalFields.map(\.label) == ["VAT ID", "Hidden"])
    }

    @Test func workflowResolvesInvoicePaymentMethodFromOverrideThenClientPreference() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000001697")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001697")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001697")!
        let preferredMethodID = UUID(uuidString: "3D410482-8EE9-4D6E-A8F5-6D7AF7458A20")!
        let overrideMethodID = UUID(uuidString: "3D410482-8EE9-4D6E-A8F5-6D7AF7458A21")!
        var profile = WorkspaceFixtures.demoWorkspace.businessProfile
        profile.paymentMethods = [
            WorkspacePaymentMethod(
                id: preferredMethodID,
                title: "Preferred",
                type: .other,
                instructions: "Preferred instructions"
            ),
            WorkspacePaymentMethod(
                id: overrideMethodID,
                title: "Override",
                type: .other,
                instructions: "Override instructions"
            ),
        ]
        profile.defaultPaymentMethodID = preferredMethodID

        let workspace = WorkspaceSnapshot(
            businessProfile: profile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Workflow Client",
                    email: "billing@workflow.example",
                    billingAddress: "1 Workflow Way",
                    defaultTermsDays: 21,
                    preferredPaymentMethodID: preferredMethodID
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
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0
                        ),
                    ],
                    invoices: []
                ),
            ],
            activity: []
        )

        let preferredResult = try WorkspaceInvoicingWorkflow().finalizeInvoice(
            workspace: workspace,
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Workflow Client",
                recipientEmail: "billing@workflow.example",
                recipientBillingAddress: "1 Workflow Way",
                invoiceNumber: "EHX-2026-697A",
                template: .kleinunternehmerClassic,
                issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
                dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: ""
            )
        )
        #expect(preferredResult.invoice.selectedPaymentMethodSnapshot?.id == preferredMethodID)

        let overrideResult = try WorkspaceInvoicingWorkflow().finalizeInvoice(
            workspace: workspace,
            projectID: projectID,
            bucketID: bucketID,
            draft: InvoiceFinalizationDraft(
                recipientName: "Workflow Client",
                recipientEmail: "billing@workflow.example",
                recipientBillingAddress: "1 Workflow Way",
                invoiceNumber: "EHX-2026-697B",
                template: .kleinunternehmerClassic,
                issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
                dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: "",
                selectedPaymentMethodID: overrideMethodID
            )
        )
        #expect(overrideResult.invoice.selectedPaymentMethodSnapshot?.id == overrideMethodID)
    }

    @Test func workflowRejectsInvalidSelectedPaymentMethod() {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001696")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001696")!
        var profile = WorkspaceFixtures.demoWorkspace.businessProfile
        profile.paymentMethods = [
            WorkspacePaymentMethod(
                id: UUID(uuidString: "3D410482-8EE9-4D6E-A8F5-6D7AF7458A22")!,
                title: "Broken",
                type: .other,
                instructions: ""
            ),
        ]
        profile.defaultPaymentMethodID = profile.paymentMethods.first?.id

        let workspace = WorkspaceSnapshot(
            businessProfile: profile,
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
                    invoices: []
                ),
            ],
            activity: []
        )

        #expect(throws: WorkspaceInvoicingWorkflowError.invalidPaymentMethodSelection) {
            try WorkspaceInvoicingWorkflow().finalizeInvoice(
                workspace: workspace,
                projectID: projectID,
                bucketID: bucketID,
                draft: InvoiceFinalizationDraft(
                    recipientName: "Workflow Client",
                    recipientEmail: "billing@workflow.example",
                    recipientBillingAddress: "1 Workflow Way",
                    invoiceNumber: "EHX-2026-696",
                    template: .kleinunternehmerClassic,
                    issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
                    dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
                    servicePeriod: "May 2026",
                    currencyCode: "EUR",
                    taxNote: ""
                )
            )
        }
    }

    @Test func workflowSnapshotsRecipientTaxLegalFieldsFromClient() throws {
        let clientID = UUID(uuidString: "10000000-0000-0000-0000-000000001698")!
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001698")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001698")!
        let workspace = WorkspaceSnapshot(
            businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
            clients: [
                WorkspaceClient(
                    id: clientID,
                    name: "Workflow Client",
                    email: "billing@workflow.example",
                    billingAddress: "1 Workflow Way",
                    defaultTermsDays: 21,
                    recipientTaxLegalFields: [
                        WorkspaceTaxLegalField(
                            label: "Client VAT",
                            value: "CH-123",
                            placement: .recipientDetails,
                            isVisible: true,
                            sortOrder: 0
                        ),
                    ]
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
                            totalMinorUnits: 10_000,
                            billableMinutes: 60,
                            fixedCostMinorUnits: 0
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
                invoiceNumber: "EHX-2026-698",
                template: .kleinunternehmerClassic,
                issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
                dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
                servicePeriod: "May 2026",
                currencyCode: "EUR",
                taxNote: ""
            )
        )

        #expect(result.invoice.clientSnapshot?.recipientTaxLegalFields.map(\.label) == ["Client VAT"])
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
                            issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
                            dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
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
                    issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
                    dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
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
            issueDate: Date.billbiDate(year: 2026, month: 5, day: 2),
            dueDate: Date.billbiDate(year: 2026, month: 5, day: 16),
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
