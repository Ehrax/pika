import SwiftUI
#if os(macOS)
import AppKit
import PDFKit
#endif
import UniformTypeIdentifiers

struct InvoicesView: View {
    @Environment(\.invoicePDFService) private var invoicePDFService

    let workspace: WorkspaceSnapshot
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    let initialSelectedInvoiceID: WorkspaceInvoice.ID?
    @State private var selectedInvoiceID: WorkspaceInvoice.ID?
    @State private var invoiceFilter = InvoiceListFilter.all
    @State private var pdfActionFailure: PDFActionFailure?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))
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

    init(
        workspace: WorkspaceSnapshot,
        workspaceStore: WorkspaceStore,
        currentDate: Date,
        initialSelectedInvoiceID: WorkspaceInvoice.ID? = nil
    ) {
        self.workspace = workspace
        self.workspaceStore = workspaceStore
        self.currentDate = currentDate
        self.initialSelectedInvoiceID = initialSelectedInvoiceID
        _selectedInvoiceID = State(initialValue: initialSelectedInvoiceID)
    }

    var body: some View {
        Group {
            if let projection {
                ResizableDetailSplitView {
                    InvoiceListColumn(
                        rows: filteredRows,
                        summary: InvoiceListSummary(rows: projection.rows),
                        filter: $invoiceFilter,
                        selectedInvoiceID: selectedInvoiceID ?? selectedRow?.id,
                        onSelect: { selectedInvoiceID = $0 }
                    )
                } detail: {
                    if let selectedRow {
                        renderedPreview(for: selectedRow)
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
                .onChange(of: initialSelectedInvoiceID) { _, newValue in
                    if let newValue {
                        invoiceFilter = .all
                        selectedInvoiceID = newValue
                    }
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
        .navigationTitle(navigationTitle)
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

    private var navigationTitle: String {
        #if os(macOS)
        ""
        #else
        "Invoices"
        #endif
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

    @ViewBuilder
    private func renderedPreview(for row: WorkspaceInvoiceRowProjection) -> some View {
        let profile = row.businessProfile ?? workspace.businessProfile
        if let rendered = try? invoicePDFService.renderInvoice(profile: profile, row: row) {
            #if os(macOS)
            MacPDFDocumentView(data: rendered.data)
            #else
            ContentUnavailableView(
                "Preview unavailable",
                systemImage: "doc.richtext",
                description: Text("PDF preview is currently available on Mac.")
            )
            #endif
        } else {
            ContentUnavailableView(
                "Preview unavailable",
                systemImage: "doc.richtext",
                description: Text("The selected invoice could not be rendered.")
            )
        }
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
        PikaSecondarySidebarColumn(
            title: "Invoices",
            subtitle: summary.displayText,
            sectionTitle: "\(filter.rawValue) Invoices",
            wrapsContentInScrollView: false
        ) {
            EmptyView()
        } controls: {
            FlowingInvoiceFilters(filter: $filter)
        } content: {
            VStack(spacing: 0) {
                Divider()
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No Invoices",
                        systemImage: "doc.text",
                        description: Text("No invoices match this status.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .foregroundStyle(PikaColor.textSecondary)
                    .padding(.top, PikaSpacing.md)
                } else {
                    invoiceList
                        .padding(.top, PikaSpacing.md)
                }
            }
        }
    }

    private var invoiceList: some View {
        List {
            ForEach(rows) { row in
                Button {
                    onSelect(row.id)
                } label: {
                    InvoiceRow(row: row, isSelected: row.id == selectedInvoiceID)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: PikaSpacing.sm, bottom: 1, trailing: PikaSpacing.sm))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(PikaColor.surface)
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
                    .foregroundStyle(filter == option ? Color.white : PikaColor.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(filter == option ? PikaColor.accent : PikaColor.surfaceAlt)
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
                    .font(PikaTypography.body.monospacedDigit().weight(isSelected ? .semibold : .medium))
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
        .pikaSecondarySidebarRow(isSelected: isSelected)
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

#if os(macOS)
private struct MacPDFDocumentView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(data: data)
    }
}
#endif
