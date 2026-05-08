import SwiftUI

struct ProjectWorkbenchView: View {
    @Environment(\.invoicePDFService) private var invoicePDFService

    let project: WorkspaceProject?
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    let initialSelectedBucketID: WorkspaceBucket.ID?
    @State private var selectedBucketID: WorkspaceBucket.ID?
    @State private var invoiceDraft: InvoiceDraftPresentation?
    @State private var actionFailure: WorkflowActionFailure?
    @State private var showsCreateBucket = false
    @State private var showsFixedCostSheet = false
    @State private var showsArchiveBucketConfirmation = false
    @State private var showsRemoveBucketConfirmation = false
    @State private var bucketPendingRemovalID: WorkspaceBucket.ID?
    @State private var showsEditBucket = false
    #if os(macOS)
    @StateObject private var invoicePreviewState = InvoiceHTMLPreviewState()
    #endif

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    init(
        project: WorkspaceProject?,
        workspaceStore: WorkspaceStore,
        currentDate: Date,
        initialSelectedBucketID: WorkspaceBucket.ID? = nil
    ) {
        self.project = project
        self.workspaceStore = workspaceStore
        self.currentDate = currentDate
        self.initialSelectedBucketID = initialSelectedBucketID
        _selectedBucketID = State(initialValue: initialSelectedBucketID)
    }

    var body: some View {
        Group {
            if let project {
                ProjectWorkbenchContent(
                    project: project,
                    currentDate: currentDate,
                    initialSelectedBucketID: initialSelectedBucketID,
                    selectedBucketID: $selectedBucketID,
                    formatter: formatter,
                    canMarkSelectedBucketReady: canMarkSelectedBucketReady,
                    invoiceRow: invoiceRow(for:in:),
                    onCreateBucket: { showsCreateBucket = true },
                    onShowFixedCostSheet: { showsFixedCostSheet = true },
                    onAddTimeEntry: addTimeEntry(projectID:bucketID:draft:),
                    onDeleteEntry: deleteEntry(projectID:bucketID:row:),
                    onUpdateEntryDate: updateEntryDate(projectID:bucketID:row:date:),
                    onMarkReady: markSelectedBucketReady,
                    onCreateInvoice: prepareInvoiceDraft(projectID:bucketID:totalLabel:lineItems:),
                    canOpenInvoicePDF: canOpenSelectedInvoicePDF,
                    onOpenInvoicePDF: openSelectedInvoicePDF,
                    onArchiveBucket: { bucketID in
                        selectedBucketID = bucketID
                        showsArchiveBucketConfirmation = true
                    },
                    onRemoveBucket: { bucketID in
                        selectedBucketID = bucketID
                        bucketPendingRemovalID = bucketID
                        showsRemoveBucketConfirmation = true
                    }
                )
            } else {
                ContentUnavailableView("Project not found", systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BillbiColor.background)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(navigationTitle)
        .toolbar {
            projectToolbar
        }
        .projectWorkbenchPresentation(
            invoiceDraft: $invoiceDraft,
            actionFailure: $actionFailure,
            showsArchiveBucketConfirmation: $showsArchiveBucketConfirmation,
            showsRemoveBucketConfirmation: $showsRemoveBucketConfirmation,
            bucketPendingRemovalID: $bucketPendingRemovalID,
            showsEditBucket: $showsEditBucket,
            showsCreateBucket: $showsCreateBucket,
            showsFixedCostSheet: $showsFixedCostSheet,
            selectedBucket: selectedBucket,
            project: project,
            currentDate: currentDate,
            archiveSelectedBucket: archiveSelectedBucket,
            removePendingBucket: removePendingBucket,
            updateSelectedBucket: updateSelectedBucket,
            createBucket: createBucket,
            addFixedCost: addFixedCost,
            finalizeInvoice: finalizeInvoice
        )
        #if os(macOS)
        .background {
            selectedInvoicePDFRenderer
        }
        #endif
    }

    @ToolbarContentBuilder
    private var projectToolbar: some ToolbarContent {
        ProjectWorkbenchToolbarContent(
            hasSelectedProject: project != nil,
            hasSelectedBucket: selectedBucket != nil,
            canMarkReady: canMarkSelectedBucketReady,
            selectedInvoiceRow: selectedInvoiceRow,
            selectedBucketStatus: selectedBucket?.status,
            canArchiveOrRestore: canArchiveOrRestoreSelectedBucket,
            canRemove: canRemoveSelectedBucket,
            onEditBucket: { showsEditBucket = true },
            onMarkReady: markSelectedBucketReady,
            onMarkInvoiceSent: markInvoiceSent,
            onMarkInvoicePaid: markInvoicePaid,
            onCancelInvoice: cancelInvoice,
            onArchiveOrRestore: {
                if selectedBucket?.status == .archived {
                    restoreSelectedBucket()
                } else {
                    showsArchiveBucketConfirmation = true
                }
            },
            onRemoveBucket: prepareRemoveSelectedBucket
        )
    }

    private var selectedBucket: WorkspaceBucket? {
        guard let project else { return nil }
        let bucketID = project.normalizedBucketID(selectedBucketID)
        return project.buckets.first { $0.id == bucketID }
    }

    private var selectedInvoiceRow: WorkspaceInvoiceRowProjection? {
        guard
            let project,
            let projection = project.detailProjection(
                selectedBucketID: selectedBucketID,
                formatter: formatter,
                on: currentDate
            )
        else {
            return nil
        }

        return invoiceRow(for: projection, in: project)
    }

    private var navigationTitle: String {
        #if os(macOS)
        ""
        #else
        project?.name ?? "Project"
        #endif
    }

    private func invoiceRow(
        for projection: WorkspaceBucketDetailProjection,
        in project: WorkspaceProject
    ) -> WorkspaceInvoiceRowProjection? {
        guard projection.selectedBucket.status == .finalized else { return nil }

        let invoice = project.invoices
            .filter {
                $0.matches(
                    projectID: project.id,
                    projectName: project.name,
                    bucketID: projection.selectedBucket.id,
                    bucketName: projection.selectedBucket.name
                )
            }
            .sorted { left, right in
                if left.issueDate == right.issueDate {
                    return left.number > right.number
                }

                return left.issueDate > right.issueDate
            }
            .first

        guard let invoice else { return nil }

        return WorkspaceInvoiceRowProjection(
            invoice: invoice,
            projectName: project.name,
            billingAddress: workspaceStore.workspace.clients.firstMatching(
                id: invoice.clientID,
                name: invoice.clientName
            )?.billingAddress ?? "",
            on: currentDate,
            formatter: formatter
        )
    }

    private var canMarkSelectedBucketReady: Bool {
        guard project?.isArchived == false, let selectedBucket else { return false }
        return selectedBucket.status == .open && selectedBucket.effectiveTotalMinorUnits > 0
    }

    private var canArchiveOrRestoreSelectedBucket: Bool {
        guard project?.isArchived == false, let selectedBucket else { return false }
        return selectedBucket.status == .archived || !selectedBucket.status.isInvoiceLocked
    }

    private var canRemoveSelectedBucket: Bool {
        guard project?.isArchived == false, let selectedBucket else { return false }
        return selectedBucket.status == .archived
    }

    private var canOpenSelectedInvoicePDF: Bool {
        #if os(macOS)
        guard let row = selectedInvoiceRow else { return false }
        return invoicePreviewState.requestedInvoiceID == row.id && invoicePreviewState.canExportSelectedDocument
        #else
        false
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var selectedInvoicePDFRenderer: some View {
        if let row = selectedInvoiceRow, let rendered = renderedInvoiceHTMLIfAvailable(for: row) {
            MacInvoiceHTMLDocumentView(
                rendered: rendered,
                invoiceID: row.id,
                state: invoicePreviewState
            )
            .frame(width: 1, height: 1)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
    #endif

    private func markSelectedBucketReady() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.markBucketReady(projectID: project.id, bucketID: bucketID)
        } catch {
            reportWorkflowActionFailure("mark_bucket_ready", error)
        }
    }

    private func updateSelectedBucket(_ draft: WorkspaceBucketDraft) {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.updateBucket(projectID: project.id, bucketID: bucketID, draft)
            showsEditBucket = false
        } catch {
            reportWorkflowActionFailure("update_bucket", error)
        }
    }

    private func archiveSelectedBucket() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.archiveBucket(projectID: project.id, bucketID: bucketID)
        } catch {
            reportWorkflowActionFailure("archive_bucket", error)
        }
    }

    private func restoreSelectedBucket() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.restoreBucket(projectID: project.id, bucketID: bucketID)
        } catch {
            reportWorkflowActionFailure("restore_bucket", error)
        }
    }

    private func prepareRemoveSelectedBucket() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }
        bucketPendingRemovalID = bucketID
        showsRemoveBucketConfirmation = true
    }

    private func removePendingBucket() {
        guard let project, let bucketID = bucketPendingRemovalID ?? project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.removeBucket(projectID: project.id, bucketID: bucketID)
            if selectedBucketID == bucketID {
                selectedBucketID = nil
            }
            bucketPendingRemovalID = nil
        } catch {
            reportWorkflowActionFailure("remove_bucket", error)
        }
    }

    private func addFixedCost(_ draft: WorkspaceFixedCostDraft) {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.addFixedCost(
                projectID: project.id,
                bucketID: bucketID,
                draft: draft
            )
            showsFixedCostSheet = false
        } catch {
            reportWorkflowActionFailure("add_fixed_cost", error)
        }
    }

    private func createBucket(_ draft: WorkspaceBucketDraft) {
        guard let project else { return }

        do {
            let bucket = try workspaceStore.createBucket(
                projectID: project.id,
                draft
            )
            selectedBucketID = bucket.id
            showsCreateBucket = false
        } catch {
            reportWorkflowActionFailure("create_bucket", error)
        }
    }

    private func addTimeEntry(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        draft: WorkspaceTimeEntryDraft
    ) {
        do {
            try workspaceStore.addTimeEntry(
                projectID: projectID,
                bucketID: bucketID,
                draft: draft
            )
        } catch {
            reportWorkflowActionFailure("add_time_entry", error)
        }
    }

    private func deleteEntry(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        row: WorkspaceBucketEntryRowProjection
    ) {
        do {
            try workspaceStore.deleteEntry(
                projectID: projectID,
                bucketID: bucketID,
                rowID: row.id,
                kind: row.kind,
                isBillable: row.isBillable
            )
        } catch {
            reportWorkflowActionFailure("delete_entry", error)
        }
    }

    private func updateEntryDate(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        row: WorkspaceBucketEntryRowProjection,
        date: Date
    ) {
        do {
            try workspaceStore.updateEntryDate(
                projectID: projectID,
                bucketID: bucketID,
                rowID: row.id,
                kind: row.kind,
                date: date
            )
        } catch {
            reportWorkflowActionFailure("update_entry_date", error)
        }
    }

    private func prepareInvoiceDraft(
        projectID: WorkspaceProject.ID,
        bucketID: WorkspaceBucket.ID,
        totalLabel: String,
        lineItems: [WorkspaceBucketLineItemProjection]
    ) {
        do {
            let draft = try workspaceStore.defaultInvoiceDraft(
                projectID: projectID,
                bucketID: bucketID,
                issueDate: currentDate
            )
            invoiceDraft = InvoiceDraftPresentation(
                projectID: projectID,
                bucketID: bucketID,
                draft: draft,
                totalLabel: totalLabel,
                lineItems: lineItems.filter(\.isBillable)
            )
        } catch {
            reportWorkflowActionFailure("prepare_invoice_draft", error)
        }
    }

    private func finalizeInvoice(
        presentation: InvoiceDraftPresentation,
        draft: InvoiceFinalizationDraft
    ) -> Bool {
        do {
            try workspaceStore.finalizeInvoice(
                projectID: presentation.projectID,
                bucketID: presentation.bucketID,
                draft: draft
            )
            invoiceDraft = nil
            return true
        } catch {
            reportWorkflowActionFailure("finalize_invoice", error)
            return false
        }
    }

    private func markInvoiceSent(_ row: WorkspaceInvoiceRowProjection) {
        do {
            try workspaceStore.markInvoiceSent(invoiceID: row.id)
        } catch {
            reportWorkflowActionFailure("mark_invoice_sent", error)
        }
    }

    private func markInvoicePaid(_ row: WorkspaceInvoiceRowProjection) {
        do {
            try workspaceStore.markInvoicePaid(invoiceID: row.id)
        } catch {
            reportWorkflowActionFailure("mark_invoice_paid", error)
        }
    }

    private func cancelInvoice(_ row: WorkspaceInvoiceRowProjection) {
        do {
            try workspaceStore.cancelInvoice(invoiceID: row.id)
        } catch {
            reportWorkflowActionFailure("cancel_invoice", error)
        }
    }

    private func openSelectedInvoicePDF() {
        #if os(macOS)
        Task { @MainActor in
            do {
                guard let row = selectedInvoiceRow else { throw PDFActionError.noSelectedInvoice }
                let renderedHTML = try renderInvoiceHTML(for: row)
                let data = try await invoicePreviewState.pdfDataForSelectedDocument()
                let renderedPDF = InvoicePDFService.RenderedInvoice(
                    data: data,
                    metadata: renderedHTML.metadata
                )
                try InvoicePDFActions.openRendered(renderedPDF)
            } catch {
                reportInvoicePDFActionFailure(error)
            }
        }
        #endif
    }

    private func renderInvoiceHTML(
        for row: WorkspaceInvoiceRowProjection
    ) throws -> InvoicePDFService.RenderedInvoiceHTML {
        try invoicePDFService.renderInvoiceHTML(
            profile: row.businessProfile ?? workspaceStore.workspace.businessProfile,
            row: row
        )
    }

    private func renderedInvoiceHTMLIfAvailable(
        for row: WorkspaceInvoiceRowProjection
    ) -> InvoicePDFService.RenderedInvoiceHTML? {
        try? renderInvoiceHTML(for: row)
    }

    private func reportInvoicePDFActionFailure(_ error: Error) {
        let message = error.localizedDescription
        actionFailure = WorkflowActionFailure(message: message)
        AppTelemetry.invoicePDFActionFailed(action: "open", message: message)
    }

    private func reportWorkflowActionFailure(_ action: String, _ error: Error) {
        let message = error.localizedDescription
        actionFailure = WorkflowActionFailure(message: "\(action): \(message)")
        AppTelemetry.projectWorkflowActionFailed(action: action, message: String(describing: error))
    }
}
