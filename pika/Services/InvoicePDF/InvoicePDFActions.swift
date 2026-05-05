import Foundation
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

enum InvoicePDFActions {
    static func open(
        invoicePDFService: InvoicePDFService,
        profile: BusinessProfileProjection,
        row: WorkspaceInvoiceRowProjection
    ) throws -> InvoicePDFService.RenderedInvoice {
        throw InvoicePDFActionsError.previewDocumentRequired
    }

    static func openRendered(_ rendered: InvoicePDFService.RenderedInvoice) throws {
        let url = try writeTemporaryPDF(rendered)

        #if os(macOS)
        guard NSWorkspace.shared.open(url) else {
            throw InvoicePDFActionsError.openFailed
        }
        AppTelemetry.invoicePDFOpened(invoiceNumber: rendered.metadata.invoiceNumber)
        #else
        throw InvoicePDFActionsError.unsupportedPlatform
        #endif
    }

    static func export(
        invoicePDFService: InvoicePDFService,
        profile: BusinessProfileProjection,
        row: WorkspaceInvoiceRowProjection
    ) throws -> InvoicePDFService.RenderedInvoice {
        throw InvoicePDFActionsError.previewDocumentRequired
    }

    static func exportRendered(_ rendered: InvoicePDFService.RenderedInvoice) throws {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = rendered.metadata.suggestedFilename

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        try rendered.data.write(to: url, options: .atomic)
        AppTelemetry.invoicePDFExported(invoiceNumber: rendered.metadata.invoiceNumber)
        #else
        throw InvoicePDFActionsError.unsupportedPlatform
        #endif
    }

    private static func writeTemporaryPDF(_ rendered: InvoicePDFService.RenderedInvoice) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Pika", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(rendered.metadata.suggestedFilename)
        try rendered.data.write(to: url, options: .atomic)
        return url
    }
}

enum InvoicePDFActionsError: LocalizedError {
    case openFailed
    case unsupportedPlatform
    case previewDocumentRequired

    var errorDescription: String? {
        switch self {
        case .openFailed:
            return "The selected PDF could not be opened."
        case .unsupportedPlatform:
            return "This PDF action is only available on Mac."
        case .previewDocumentRequired:
            return "Open the invoice preview before generating a PDF."
        }
    }
}
