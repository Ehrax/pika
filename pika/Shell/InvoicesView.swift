import SwiftUI
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

struct InvoicesView: View {
    @Environment(\.invoicePDFService) private var invoicePDFService

    let workspace: WorkspaceSnapshot
    let currentDate: Date
    @State private var selectedInvoiceID: WorkspaceInvoice.ID?
    @State private var pdfActionFailure: PDFActionFailure?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
    private let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted)

    private var projection: WorkspaceInvoicePreviewProjection? {
        workspace.invoicePreviewProjection(
            selectedInvoiceID: selectedInvoiceID,
            on: currentDate,
            formatter: formatter
        )
    }

    var body: some View {
        Group {
            if let projection {
                HStack(spacing: 0) {
                    InvoiceListColumn(
                        projection: projection,
                        selectedInvoiceID: selectedInvoiceID ?? projection.selectedInvoice.id,
                        onSelect: { selectedInvoiceID = $0 }
                    )

                    PDFPreviewPlaceholder(
                        profile: workspace.businessProfile,
                        row: projection.selectedRow,
                        dateStyle: dateStyle
                    )
                }
                .onAppear {
                    selectedInvoiceID = selectedInvoiceID ?? projection.selectedInvoice.id
                    AppTelemetry.invoicesLoaded(invoiceCount: projection.rows.count)
                }
            } else {
                ContentUnavailableView(
                    "No Invoices",
                    systemImage: "doc.text",
                    description: Text("Finalize a ready bucket to preview invoices here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PikaColor.background)
        .navigationTitle("Invoices")
        .toolbar {
            Button {
                openSelectedPDF()
            } label: {
                Label("Open PDF", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(projection == nil)
            .help("Open the selected invoice PDF")

            Button {
                exportSelectedPDF()
            } label: {
                Label("Export PDF", systemImage: "arrow.down.doc")
            }
            .disabled(projection == nil)
            .help("Export the selected invoice PDF")

            Button {
            } label: {
                Label("Mark Sent", systemImage: "paperplane")
            }
            .disabled(true)
            .help("Invoice status actions land in the invoice workflow")
        }
        .alert(item: $pdfActionFailure) { failure in
            Alert(
                title: Text("PDF Action Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .accessibilityIdentifier("InvoicesView")
    }

    private func openSelectedPDF() {
        performPDFAction("open") {
            let rendered = try renderSelectedInvoice()
            let url = try writeTemporaryPDF(rendered)

            #if os(macOS)
            guard NSWorkspace.shared.open(url) else {
                throw PDFActionError.openFailed
            }
            AppTelemetry.invoicePDFOpened(invoiceNumber: rendered.metadata.invoiceNumber)
            #else
            throw PDFActionError.unsupportedPlatform
            #endif
        }
    }

    private func exportSelectedPDF() {
        performPDFAction("export") {
            let rendered = try renderSelectedInvoice()

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
            throw PDFActionError.unsupportedPlatform
            #endif
        }
    }

    private func performPDFAction(_ action: String, operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            let message = error.localizedDescription
            pdfActionFailure = PDFActionFailure(message: message)
            AppTelemetry.invoicePDFActionFailed(action: action, message: message)
        }
    }

    private func renderSelectedInvoice() throws -> InvoicePDFService.RenderedInvoice {
        guard let row = projection?.selectedRow else {
            throw PDFActionError.noSelectedInvoice
        }

        return try invoicePDFService.renderInvoice(
            profile: workspace.businessProfile,
            row: row
        )
    }

    private func writeTemporaryPDF(_ rendered: InvoicePDFService.RenderedInvoice) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Pika", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(rendered.metadata.suggestedFilename)
        try rendered.data.write(to: url, options: .atomic)
        return url
    }
}

private struct PDFActionFailure: Identifiable {
    let id = UUID()
    let message: String
}

private enum PDFActionError: LocalizedError {
    case noSelectedInvoice
    case openFailed
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .noSelectedInvoice:
            return "Select an invoice before opening or exporting a PDF."
        case .openFailed:
            return "The selected PDF could not be opened."
        case .unsupportedPlatform:
            return "This PDF action is only available on Mac."
        }
    }
}

private struct InvoiceListColumn: View {
    let projection: WorkspaceInvoicePreviewProjection
    let selectedInvoiceID: WorkspaceInvoice.ID
    let onSelect: (WorkspaceInvoice.ID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    Text("Invoices")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)

                    VStack(spacing: 2) {
                        ForEach(projection.rows) { row in
                            Button {
                                onSelect(row.id)
                            } label: {
                                InvoiceRow(row: row, isSelected: row.id == selectedInvoiceID)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(PikaSpacing.lg)
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
        .frame(maxHeight: .infinity)
        .background(PikaColor.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PikaColor.border)
                .frame(width: 1)
        }
    }
}

private struct InvoiceRow: View {
    let row: WorkspaceInvoiceRowProjection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.number)
                    .font(.body.monospacedDigit().weight(.medium))
                    .foregroundStyle(PikaColor.textPrimary)
                Text(row.clientName)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(row.totalLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(PikaColor.textPrimary)
                StatusBadge(row.isOverdue ? .danger : .neutral, title: row.statusTitle)
            }
        }
        .padding(PikaSpacing.sm)
        .background(isSelected ? PikaColor.surfaceAlt : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? PikaColor.accent : Color.clear)
                .frame(width: 2)
        }
    }
}

private struct PDFPreviewPlaceholder: View {
    let profile: BusinessProfileProjection
    let row: WorkspaceInvoiceRowProjection
    let dateStyle: Date.FormatStyle

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: PikaSpacing.md) {
                            HStack(spacing: PikaSpacing.sm) {
                                Text("p")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: PikaRadius.sm))
                                Text(profile.businessName)
                                    .font(.headline.weight(.semibold))
                            }

                            Text("\(profile.address)\n\(profile.email)")
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.35))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: PikaSpacing.xs) {
                            Text("Invoice")
                                .font(.title2.weight(.semibold))
                            Text(row.number)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color(white: 0.35))
                        }
                    }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                            Text("Bill to")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(white: 0.35))
                            Text(row.clientName)
                                .font(.body.weight(.medium))
                            Text(row.billingAddress)
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.35))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: PikaSpacing.xs) {
                            Text("Issue \(row.issueDate.formatted(dateStyle))")
                            Text("Due \(row.dueDate.formatted(dateStyle))")
                            Text(row.statusTitle)
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(white: 0.35))
                    }

                    VStack(spacing: 0) {
                        PDFLine(description: "Invoice line preview", amount: row.totalLabel)
                        PDFLine(description: "PDF-ready metadata", amount: "Included")
                    }

                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: PikaSpacing.xs) {
                            Text("Total")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(white: 0.35))
                            Text(row.totalLabel)
                                .font(.title2.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .foregroundStyle(Color.black)
                .padding(48)
                .frame(width: 540, alignment: .topLeading)
                .frame(minHeight: 760, alignment: .topLeading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .shadow(color: .black.opacity(0.32), radius: 24, y: 10)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PikaColor.background)
    }
}

private struct PDFLine: View {
    let description: String
    let amount: String

    var body: some View {
        HStack {
            Text(description)
            Spacer()
            Text(amount)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.9))
                .frame(height: 1)
        }
    }
}
