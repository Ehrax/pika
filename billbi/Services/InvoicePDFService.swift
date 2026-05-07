import Foundation
import OSLog

struct InvoicePDFService {
    enum Error: Swift.Error, Equatable {
        case notImplemented
        case renderingFailed
    }

    struct RenderedInvoice: Equatable {
        var data: Data
        var metadata: Metadata
    }

    struct RenderedInvoiceHTML: Equatable {
        var html: String
        var metadata: Metadata
        var templateFolderName: String
        var resourceBaseURL: URL?
    }

    struct Metadata: Equatable {
        var invoiceNumber: String
        var clientName: String
        var projectName: String
        var bucketName: String
        var templateName: String
        var currencyCode: String
        var totalLabel: String
        var lineItemCount: Int
        var pageCount: Int
        var suggestedFilename: String
    }

    static func placeholder() -> InvoicePDFService {
        InvoicePDFService()
    }

    func renderDraftPDF() throws -> Data {
        throw Error.notImplemented
    }

    func renderInvoiceHTML(
        profile: BusinessProfileProjection,
        row: WorkspaceInvoiceRowProjection
    ) throws -> RenderedInvoiceHTML {
        let context = InvoiceRenderContext(profile: row.businessProfile ?? profile, row: row)
        let resources = try InvoiceTemplateResources(template: row.template)
        let html = try InvoiceHTMLTemplateRenderer().render(context, resources: resources)

        Self.logger.info(
            "Rendered invoice HTML \(context.metadata.invoiceNumber, privacy: .public) for \(context.metadata.clientName, privacy: .public)"
        )

        return RenderedInvoiceHTML(
            html: html,
            metadata: context.metadata,
            templateFolderName: row.template.resourceFolderName,
            resourceBaseURL: resources.baseURL
        )
    }

    private static let logger = Logger(subsystem: "dev.ehrax.billbi", category: "InvoicePDFService")
}
