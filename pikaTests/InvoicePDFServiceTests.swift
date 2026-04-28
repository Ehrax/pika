import Foundation
import Testing
@testable import pika

struct InvoicePDFServiceTests {
    @Test func renderInvoiceReturnsPDFDataAndInvoiceMetadata() throws {
        let workspace = WorkspaceSnapshot.sample
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let projection = try #require(
            workspace.invoicePreviewProjection(
                selectedInvoiceID: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                on: WorkspaceSnapshot.sampleToday,
                formatter: formatter
            )
        )
        let service = InvoicePDFService.placeholder()

        let rendered = try service.renderInvoice(
            profile: workspace.businessProfile,
            row: projection.selectedRow
        )

        #expect(rendered.data.count > 1_000)
        #expect(String(decoding: rendered.data.prefix(4), as: UTF8.self) == "%PDF")
        #expect(rendered.metadata.invoiceNumber == "EHX-2026-004")
        #expect(rendered.metadata.clientName == "Northstar Labs")
        #expect(rendered.metadata.projectName == "Mobile QA")
        #expect(rendered.metadata.bucketName == "Regression pass")
        #expect(rendered.metadata.templateName == "Classic")
        #expect(rendered.metadata.currencyCode == "EUR")
        #expect(rendered.metadata.totalLabel == "EUR 1,200.00")
        #expect(rendered.metadata.lineItemCount == 1)
        #expect(rendered.metadata.pageCount == 1)
        #expect(rendered.metadata.suggestedFilename == "EHX-2026-004-Northstar-Labs.pdf")
    }

    @Test func renderInvoiceContinuesPDFWhenInvoiceHasMoreThanFiveLineItems() throws {
        let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
        let invoice = WorkspaceInvoice(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000099")!,
            number: "EHX-2026-099",
            clientName: "Northstar Labs",
            projectName: "Mobile QA",
            bucketName: "Regression pass",
            issueDate: Date(timeIntervalSince1970: 1_775_491_200),
            dueDate: Date(timeIntervalSince1970: 1_776_700_800),
            status: .finalized,
            totalMinorUnits: 210_000,
            lineItems: (1...12).map { index in
                WorkspaceInvoiceLineItemSnapshot(
                    description: "Invoice work item \(index)",
                    quantityLabel: "1h",
                    amountMinorUnits: 17_500
                )
            }
        )
        let row = WorkspaceInvoiceRowProjection(
            invoice: invoice,
            projectName: "Mobile QA",
            billingAddress: "12 Polaris Yard, Berlin",
            on: WorkspaceSnapshot.sampleToday,
            formatter: formatter
        )
        let service = InvoicePDFService.placeholder()

        let rendered = try service.renderInvoice(
            profile: WorkspaceSnapshot.sample.businessProfile,
            row: row
        )

        #expect(String(decoding: rendered.data.prefix(4), as: UTF8.self) == "%PDF")
        #expect(rendered.metadata.lineItemCount == 12)
        #expect(rendered.metadata.pageCount == 2)
    }
}
