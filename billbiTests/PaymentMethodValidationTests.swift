import Foundation
import SwiftData
import Testing
@testable import billbi

struct PaymentMethodValidationTests {
    @Test func everyV1PaymentMethodTypeCanProduceValidPrintableInstructions() {
        let methods = [
            WorkspacePaymentMethod(
                title: "SEPA",
                type: .sepaBankTransfer,
                accountHolder: "North Coast Studio",
                iban: "DE02 1001 1001 2125 8144 33",
                bic: "NTSBDEB1XXX"
            ),
            WorkspacePaymentMethod(
                title: "International",
                type: .internationalBankTransfer,
                accountHolder: "North Coast Studio",
                iban: "GB82 WEST 1234 5698 7654 32",
                bic: "DEUTDEFF"
            ),
            WorkspacePaymentMethod(
                title: "PayPal",
                type: .paypal,
                email: "billing@example.com"
            ),
            WorkspacePaymentMethod(
                title: "Wise",
                type: .wise,
                url: "https://wise.com/pay/me/northcoast"
            ),
            WorkspacePaymentMethod(
                title: "Payment link",
                type: .paymentLink,
                url: "https://pay.example.com/invoices"
            ),
            WorkspacePaymentMethod(
                title: "Other",
                type: .other,
                instructions: "Pay via the local bank details we agreed."
            ),
        ]

        #expect(methods.allSatisfy { $0.isValidForInvoiceFinalization })
        #expect(methods.map(\.type) == WorkspacePaymentMethodType.allCases)
    }

    @Test func knownPaymentMethodFormatsBlockInvalidPrintableInstructions() {
        let invalidMethods = [
            WorkspacePaymentMethod(title: "Broken IBAN", type: .sepaBankTransfer, iban: "DE00 1234"),
            WorkspacePaymentMethod(title: "Broken BIC", type: .internationalBankTransfer, iban: "GB82 WEST 1234 5698 7654 32", bic: "NO"),
            WorkspacePaymentMethod(title: "Broken PayPal", type: .paypal, email: "not an email"),
            WorkspacePaymentMethod(title: "Broken Link", type: .paymentLink, url: "pay me later"),
            WorkspacePaymentMethod(title: "Empty Other", type: .other, instructions: "   "),
        ]

        #expect(invalidMethods.allSatisfy { !$0.validation.blockingMessages.isEmpty })
        #expect(invalidMethods.allSatisfy { !$0.isValidForInvoiceFinalization })
    }

    @Test func workflowRejectsInvalidPaymentMethodFormats() {
        let projectID = UUID(uuidString: "20000000-0000-0000-0000-000000001699")!
        let bucketID = UUID(uuidString: "30000000-0000-0000-0000-000000001699")!
        var profile = WorkspaceFixtures.demoWorkspace.businessProfile
        profile.paymentMethods = [
            WorkspacePaymentMethod(
                id: UUID(uuidString: "3D410482-8EE9-4D6E-A8F5-6D7AF7458A23")!,
                title: "Broken link",
                type: .paymentLink,
                url: "pay me later"
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
                    invoiceNumber: "EHX-2026-695",
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

    @Test func businessProfileCanSaveStructuredPaymentMethodWithoutLegacyPaymentDetails() throws {
        let (modelContext, _) = try makePersistentModelContext()
        let store = WorkspaceStore(
            seed: WorkspaceSnapshot(
                businessProfile: WorkspaceFixtures.demoWorkspace.businessProfile,
                clients: [],
                projects: [],
                activity: []
            ),
            modelContext: modelContext
        )
        let methodID = UUID(uuidString: "3D410482-8EE9-4D6E-A8F5-6D7AF7458A24")!

        try store.updateBusinessProfile(WorkspaceBusinessProfileDraft(
            businessName: "North Coast Studio",
            email: "billing@north.example",
            phone: "",
            address: "9 Harbour Road",
            taxIdentifier: "",
            invoicePrefix: "NCS",
            nextInvoiceNumber: 42,
            currencyCode: "EUR",
            paymentDetails: "",
            paymentMethods: [
                WorkspacePaymentMethod(
                    id: methodID,
                    title: "Payment link",
                    type: .paymentLink,
                    url: "https://pay.example.com/invoices"
                ),
            ],
            defaultPaymentMethodID: methodID,
            taxNote: "",
            defaultTermsDays: 14
        ))

        #expect(store.workspace.businessProfile.paymentDetails == "")
        #expect(store.workspace.businessProfile.defaultPaymentMethodID == methodID)
    }
}
