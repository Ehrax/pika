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
        let rendered = try invoicePDFService.renderInvoice(profile: profile, row: row)
        let url = try writeTemporaryPDF(rendered)

        #if os(macOS)
        guard NSWorkspace.shared.open(url) else {
            throw InvoicePDFActionsError.openFailed
        }
        AppTelemetry.invoicePDFOpened(invoiceNumber: rendered.metadata.invoiceNumber)
        #else
        throw InvoicePDFActionsError.unsupportedPlatform
        #endif
        return rendered
    }

    static func export(
        invoicePDFService: InvoicePDFService,
        profile: BusinessProfileProjection,
        row: WorkspaceInvoiceRowProjection
    ) throws -> InvoicePDFService.RenderedInvoice {
        let rendered = try invoicePDFService.renderInvoice(profile: profile, row: row)

        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = rendered.metadata.suggestedFilename

        guard panel.runModal() == .OK, let url = panel.url else {
            return rendered
        }

        try rendered.data.write(to: url, options: .atomic)
        AppTelemetry.invoicePDFExported(invoiceNumber: rendered.metadata.invoiceNumber)
        #else
        throw InvoicePDFActionsError.unsupportedPlatform
        #endif
        return rendered
    }

    private static func writeTemporaryPDF(_ rendered: InvoicePDFService.RenderedInvoice) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Billbi", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(rendered.metadata.suggestedFilename)
        try rendered.data.write(to: url, options: .atomic)
        return url
    }
}

enum InvoicePDFActionsError: LocalizedError {
    case openFailed
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .openFailed:
            return "The selected PDF could not be opened."
        case .unsupportedPlatform:
            return "This PDF action is only available on Mac."
        }
    }
}
