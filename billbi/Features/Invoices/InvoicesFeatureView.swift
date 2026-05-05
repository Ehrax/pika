import SwiftUI

struct InvoicesFeatureView: View {
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
                        .background(BillbiColor.background)
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
        .background(BillbiColor.background)
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
        guard let status = selectedInvoice?.status else { return false }
        return InvoiceWorkflowPolicy.canMarkSent(status: status)
    }

    private var canMarkSelectedInvoicePaid: Bool {
        guard let status = selectedInvoice?.status else { return false }
        return InvoiceWorkflowPolicy.canMarkPaid(status: status)
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
            guard let row = selectedRow else { throw PDFActionError.noSelectedInvoice }
            _ = try InvoicePDFActions.open(
                invoicePDFService: invoicePDFService,
                profile: row.businessProfile ?? workspace.businessProfile,
                row: row
            )
        }
    }

    private func exportSelectedPDF() {
        performPDFAction("export") {
            guard let row = selectedRow else { throw PDFActionError.noSelectedInvoice }
            _ = try InvoicePDFActions.export(
                invoicePDFService: invoicePDFService,
                profile: row.businessProfile ?? workspace.businessProfile,
                row: row
            )
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

    var errorDescription: String? {
        switch self {
        case .noSelectedInvoice:
            return "Select an invoice before opening or exporting a PDF."
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
        BillbiSecondarySidebarColumn(
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
                    .foregroundStyle(BillbiColor.textSecondary)
                    .padding(.top, BillbiSpacing.md)
                } else {
                    invoiceList
                        .padding(.top, BillbiSpacing.md)
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
                .listRowInsets(EdgeInsets(top: 1, leading: BillbiSpacing.sm, bottom: 1, trailing: BillbiSpacing.sm))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BillbiColor.surface)
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
                            .font(BillbiTypography.small.weight(filter == option ? .medium : .regular))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(filter == option ? Color.white : BillbiColor.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(filter == option ? BillbiColor.accent : BillbiColor.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
                    .overlay {
                        RoundedRectangle(cornerRadius: BillbiRadius.pill)
                            .stroke(filter == option ? BillbiColor.accent : BillbiColor.border)
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
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: row.statusIconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.number)
                    .font(BillbiTypography.body.monospacedDigit().weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(row.clientName)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
                    .lineLimit(1)
                Text(row.bucketName)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)

            VStack(alignment: .trailing, spacing: 5) {
                Text(row.totalLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                StatusBadge(row.statusTone, title: row.statusTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: isSelected)
    }
}

private extension WorkspaceInvoiceRowProjection {
    var statusTone: BillbiStatusTone {
        InvoiceWorkflowPolicy.statusTone(status: status, isOverdue: isOverdue)
    }

    var statusIconName: String {
        InvoiceWorkflowPolicy.statusIconName(status: status, isOverdue: isOverdue)
    }
}
