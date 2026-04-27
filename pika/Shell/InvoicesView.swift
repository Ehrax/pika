import SwiftUI
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

struct InvoicesView: View {
    @Environment(\.invoicePDFService) private var invoicePDFService

    let workspace: WorkspaceSnapshot
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    @State private var selectedInvoiceID: WorkspaceInvoice.ID?
    @State private var invoiceFilter = InvoiceListFilter.all
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

    private var filteredRows: [WorkspaceInvoiceRowProjection] {
        projection?.rows.filter(invoiceFilter.includes) ?? []
    }

    private var selectedRow: WorkspaceInvoiceRowProjection? {
        filteredRows.first { $0.id == selectedInvoiceID } ?? filteredRows.first
    }

    var body: some View {
        Group {
            if let projection {
                HStack(spacing: 0) {
                    InvoiceListColumn(
                        rows: filteredRows,
                        summary: InvoiceListSummary(rows: projection.rows),
                        filter: $invoiceFilter,
                        selectedInvoiceID: selectedInvoiceID ?? selectedRow?.id,
                        onSelect: { selectedInvoiceID = $0 }
                    )

                    if let selectedRow {
                        PDFPreviewPlaceholder(
                            profile: selectedRow.businessProfile ?? workspace.businessProfile,
                            row: selectedRow,
                            dateStyle: dateStyle
                        )
                    } else {
                        ContentUnavailableView(
                            "No Matching Invoices",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Change the status filter to show invoices.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PikaColor.background)
                    }
                }
                .onAppear {
                    selectedInvoiceID = selectedInvoiceID ?? selectedRow?.id ?? projection.selectedInvoice.id
                    AppTelemetry.invoicesLoaded(invoiceCount: projection.rows.count)
                }
                .onChange(of: invoiceFilter) { _, _ in
                    selectedInvoiceID = filteredRows.first?.id
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
            .disabled(selectedRow == nil)
            .help("Open the selected invoice PDF")

            Button {
                exportSelectedPDF()
            } label: {
                Label("Export PDF", systemImage: "arrow.down.doc")
            }
            .disabled(selectedRow == nil)
            .help("Export the selected invoice PDF")

            Button {
                markSelectedInvoiceSent()
            } label: {
                Label("Mark Sent", systemImage: "paperplane")
            }
            .disabled(!canMarkSelectedInvoiceSent)
            .help("Mark the selected invoice sent")

            Button {
                markSelectedInvoicePaid()
            } label: {
                Label("Mark Paid", systemImage: "checkmark.seal")
            }
            .disabled(!canMarkSelectedInvoicePaid)
            .help("Mark the selected invoice paid")
        }
        .alert(item: $pdfActionFailure) { failure in
            Alert(
                title: Text("Invoice Action Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .accessibilityIdentifier("InvoicesView")
    }

    private var selectedInvoice: WorkspaceInvoice? {
        selectedRow?.invoice
    }

    private var canMarkSelectedInvoiceSent: Bool {
        selectedInvoice?.status == .finalized
    }

    private var canMarkSelectedInvoicePaid: Bool {
        guard let status = selectedInvoice?.status else { return false }
        return status == .finalized || status == .sent
    }

    private func markSelectedInvoiceSent() {
        guard let invoiceID = selectedInvoice?.id else { return }

        do {
            try workspaceStore.markInvoiceSent(invoiceID: invoiceID)
        } catch {
            pdfActionFailure = PDFActionFailure(message: error.localizedDescription)
        }
    }

    private func markSelectedInvoicePaid() {
        guard let invoiceID = selectedInvoice?.id else { return }

        do {
            try workspaceStore.markInvoicePaid(invoiceID: invoiceID)
        } catch {
            pdfActionFailure = PDFActionFailure(message: error.localizedDescription)
        }
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
        guard let row = selectedRow else {
            throw PDFActionError.noSelectedInvoice
        }

        return try invoicePDFService.renderInvoice(
            profile: row.businessProfile ?? workspace.businessProfile,
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

private enum InvoiceListFilter: String, CaseIterable, Equatable, Identifiable {
    case all = "All"
    case finalized = "Finalized"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"

    var id: String { rawValue }

    func includes(_ row: WorkspaceInvoiceRowProjection) -> Bool {
        switch self {
        case .all:
            true
        case .finalized:
            row.status == .finalized && !row.isOverdue
        case .sent:
            row.status == .sent && !row.isOverdue
        case .paid:
            row.status == .paid
        case .overdue:
            row.isOverdue
        case .cancelled:
            row.status == .cancelled
        }
    }
}

private struct InvoiceListSummary {
    let total: Int
    let finalized: Int
    let sent: Int
    let paid: Int
    let overdue: Int
    let cancelled: Int

    init(rows: [WorkspaceInvoiceRowProjection]) {
        total = rows.count
        finalized = rows.filter { $0.status == .finalized && !$0.isOverdue }.count
        sent = rows.filter { $0.status == .sent && !$0.isOverdue }.count
        paid = rows.filter { $0.status == .paid }.count
        overdue = rows.filter(\.isOverdue).count
        cancelled = rows.filter { $0.status == .cancelled }.count
    }

    var displayText: String {
        "\(total) total · \(finalized) finalized · \(sent) sent · \(paid) paid · \(overdue) overdue · \(cancelled) cancelled"
    }
}

private struct InvoiceListColumn: View {
    let rows: [WorkspaceInvoiceRowProjection]
    let summary: InvoiceListSummary
    @Binding var filter: InvoiceListFilter
    let selectedInvoiceID: WorkspaceInvoice.ID?
    let onSelect: (WorkspaceInvoice.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No Invoices",
                        systemImage: "doc.text",
                        description: Text("No invoices match this status.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .foregroundStyle(PikaColor.textSecondary)
                } else {
                    VStack(spacing: 2) {
                        ForEach(rows) { row in
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
                    .padding(.horizontal, PikaSpacing.sm)
                    .padding(.bottom, PikaSpacing.md)
                }
            }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Invoices")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)
                    Text(summary.displayText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PikaColor.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            FlowingInvoiceFilters(filter: $filter)
        }
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, PikaSpacing.md)
    }
}

private struct FlowingInvoiceFilters: View {
    @Binding var filter: InvoiceListFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(InvoiceListFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.rawValue)
                            .font(PikaTypography.small.weight(filter == option ? .medium : .regular))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(filter == option ? PikaColor.textPrimary : PikaColor.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(filter == option ? PikaColor.accentMuted : PikaColor.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: PikaRadius.pill))
                    .overlay {
                        RoundedRectangle(cornerRadius: PikaRadius.pill)
                            .stroke(filter == option ? PikaColor.accent : PikaColor.border)
                    }
                }
            }
            .padding(.vertical, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InvoiceRow: View {
    let row: WorkspaceInvoiceRowProjection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            Image(systemName: row.statusIconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.number)
                    .font(.body.monospacedDigit().weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(PikaColor.textPrimary)
                    .lineLimit(1)
                Text(row.clientName)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textSecondary)
                    .lineLimit(1)
                Text(row.bucketName)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PikaColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: PikaSpacing.sm)

            VStack(alignment: .trailing, spacing: 5) {
                Text(row.totalLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(PikaColor.textPrimary)
                StatusBadge(row.statusTone, title: row.statusTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, 10)
        .background(isSelected ? PikaColor.surfaceAlt : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? PikaColor.accent : Color.clear)
                .frame(width: 2)
        }
    }
}

private extension WorkspaceInvoiceRowProjection {
    var statusTone: PikaStatusTone {
        if isOverdue { return .danger }

        switch status {
        case .finalized:
            return .warning
        case .sent:
            return .neutral
        case .paid:
            return .success
        case .cancelled:
            return .neutral
        }
    }

    var statusIconName: String {
        if isOverdue { return "exclamationmark.circle" }

        switch status {
        case .finalized:
            return "doc.text"
        case .sent:
            return "paperplane"
        case .paid:
            return "checkmark.seal"
        case .cancelled:
            return "xmark.circle"
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
