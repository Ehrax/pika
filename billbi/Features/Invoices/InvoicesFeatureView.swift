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
    #if os(macOS)
    @StateObject private var invoicePreviewState = InvoiceHTMLPreviewState()
    #endif

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
            .disabled(!canExportSelectedInvoice)
            .help("Open the selected invoice PDF")

            Button {
                exportSelectedPDF()
            } label: {
                Label("Export PDF", systemImage: "arrow.down.doc")
            }
            .disabled(!canExportSelectedInvoice)
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
        String(localized: "Invoices")
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

    private var canExportSelectedInvoice: Bool {
        #if os(macOS)
        selectedRow != nil && invoicePreviewState.canExportSelectedDocument
        #else
        selectedRow != nil
        #endif
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
        #if os(macOS)
        Task {
            await performRenderedPDFAction("open", action: InvoicePDFActions.openRendered)
        }
        #else
        performPDFAction("open") {
            guard let row = selectedRow else { throw PDFActionError.noSelectedInvoice }
            _ = try InvoicePDFActions.open(
                invoicePDFService: invoicePDFService,
                profile: row.businessProfile ?? workspace.businessProfile,
                row: row
            )
        }
        #endif
    }

    private func exportSelectedPDF() {
        #if os(macOS)
        Task {
            await performRenderedPDFAction("export", action: InvoicePDFActions.exportRendered)
        }
        #else
        performPDFAction("export") {
            guard let row = selectedRow else { throw PDFActionError.noSelectedInvoice }
            _ = try InvoicePDFActions.export(
                invoicePDFService: invoicePDFService,
                profile: row.businessProfile ?? workspace.businessProfile,
                row: row
            )
        }
        #endif
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

    #if os(macOS)
    @MainActor
    private func performRenderedPDFAction(
        _ action: String,
        action perform: (InvoicePDFService.RenderedInvoice) throws -> Void
    ) async {
        do {
            guard let row = selectedRow else { throw PDFActionError.noSelectedInvoice }
            let html = try invoicePDFService.renderInvoiceHTML(
                profile: row.businessProfile ?? workspace.businessProfile,
                row: row
            )
            let data = try await invoicePreviewState.pdfDataForSelectedDocument()
            try perform(InvoicePDFService.RenderedInvoice(data: data, metadata: html.metadata))
        } catch {
            let message = error.localizedDescription
            pdfActionFailure = PDFActionFailure(message: message)
            AppTelemetry.invoicePDFActionFailed(action: action, message: message)
        }
    }
    #endif

    @ViewBuilder
    private func renderedPreview(for row: WorkspaceInvoiceRowProjection) -> some View {
        let profile = row.businessProfile ?? workspace.businessProfile
        if let rendered = try? invoicePDFService.renderInvoiceHTML(profile: profile, row: row) {
            #if os(macOS)
            MacInvoiceHTMLDocumentView(
                rendered: rendered,
                invoiceID: row.id,
                state: invoicePreviewState
            )
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
