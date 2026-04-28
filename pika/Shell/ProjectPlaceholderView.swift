import SwiftUI
#if os(macOS)
import AppKit
#endif
import UniformTypeIdentifiers

struct ProjectPlaceholderView: View {
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
                let projection = project.detailProjection(
                    selectedBucketID: selectedBucketID,
                    formatter: formatter,
                    on: currentDate
                )
                ResizableDetailSplitView {
                    if let projection {
                        let activeBucketID = project.normalizedBucketID(selectedBucketID) ?? projection.selectedBucket.id
                        ProjectBucketColumn(
                            project: project,
                            projection: projection,
                            selectedBucketID: activeBucketID,
                            onSelect: { bucketID in
                                selectedBucketID = bucketID
                                AppTelemetry.projectBucketSelected(projectName: project.name)
                            },
                            onCreateBucket: { showsCreateBucket = true },
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
                        PikaSecondarySidebarColumn(
                            title: project.name,
                            subtitle: project.clientName,
                            sectionTitle: "Buckets",
                            wrapsContentInScrollView: false
                        ) {
                            Button {
                                showsCreateBucket = true
                            } label: {
                                Label("Create a bucket", systemImage: "plus")
                            }
                            .buttonStyle(PikaColumnHeaderIconButtonStyle(foreground: PikaColor.actionAccent))
                            .help("Create a bucket")
                        } controls: {
                            EmptyView()
                        } content: {
                            VStack(spacing: 0) {
                                Divider()
                                List { EmptyView() }
                                    .listStyle(.plain)
                                    .scrollContentBackground(.hidden)
                                    .background(PikaColor.surface)
                                    .padding(.top, PikaSpacing.md)
                            }
                        }
                    }
                } detail: {
                    if let projection {
                        BucketDetailWorkbench(
                            projection: projection,
                            draftDate: currentDate,
                            invoiceRow: invoiceRow(for: projection, in: project),
                            canMarkReady: canMarkSelectedBucketReady,
                            onAddEntry: { draft in
                                addTimeEntry(
                                    projectID: project.id,
                                    bucketID: projection.selectedBucket.id,
                                    draft: draft
                                )
                            },
                            onAddFixedCost: { showsFixedCostSheet = true },
                            onDeleteEntry: { row in
                                deleteEntry(
                                    projectID: project.id,
                                    bucketID: projection.selectedBucket.id,
                                    row: row
                                )
                            },
                            onMarkReady: markSelectedBucketReady,
                            onCreateInvoice: {
                                prepareInvoiceDraft(
                                    projectID: project.id,
                                    bucketID: projection.selectedBucket.id,
                                    totalLabel: projection.totalLabel,
                                    lineItems: projection.lineItems
                                )
                            },
                            onOpenInvoicePDF: openInvoicePDF,
                            onExportInvoicePDF: exportInvoicePDF
                        )
                    } else {
                        PikaColor.background
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(PikaColor.background)
                .onAppear {
                    if let projection {
                        selectedBucketID = project.normalizedBucketID(selectedBucketID) ?? projection.selectedBucket.id
                        AppTelemetry.projectDetailLoaded(projectName: project.name, bucketCount: projection.bucketRows.count)
                    }
                }
                .onChange(of: project.id) { _, _ in
                    selectedBucketID = nil
                }
                .onChange(of: initialSelectedBucketID) { _, newValue in
                    if let newValue {
                        selectedBucketID = newValue
                    }
                }
            } else {
                ContentUnavailableView("Project not found", systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PikaColor.background)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(navigationTitle)
        .toolbar {
            projectToolbar
        }
        .confirmationDialog(
            "Archive this bucket?",
            isPresented: $showsArchiveBucketConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Bucket", role: .destructive) {
                archiveSelectedBucket()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived buckets stay in the project history, but are locked for new entries.")
        }
        .confirmationDialog(
            "Remove this bucket?",
            isPresented: $showsRemoveBucketConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Bucket", role: .destructive) {
                removePendingBucket()
            }

            Button("Cancel", role: .cancel) {
                bucketPendingRemovalID = nil
            }
        } message: {
            Text("Removed buckets are deleted from this project. This action cannot be undone.")
        }
        .sheet(item: $invoiceDraft) { presentation in
            CreateInvoiceConfirmationSheet(
                presentation: presentation,
                onCancel: { invoiceDraft = nil },
                onSave: { draft in
                    finalizeInvoice(presentation: presentation, draft: draft)
                }
            )
        }
        .sheet(isPresented: $showsEditBucket) {
            if let selectedBucket, let project {
                CreateBucketSheet(
                    defaultRateMinorUnits: selectedBucket.hourlyRateMinorUnits ?? 8_000,
                    currencyCode: project.currencyCode,
                    initialName: selectedBucket.name,
                    saveLabel: "Save Bucket",
                    saveSystemImage: "checkmark.circle",
                    onCancel: { showsEditBucket = false },
                    onSave: updateSelectedBucket
                )
            }
        }
        .sheet(isPresented: $showsCreateBucket) {
            CreateBucketSheet(
                defaultRateMinorUnits: selectedBucket?.hourlyRateMinorUnits ?? 8_000,
                currencyCode: project?.currencyCode ?? "EUR",
                onCancel: { showsCreateBucket = false },
                onSave: createBucket
            )
        }
        .sheet(isPresented: $showsFixedCostSheet) {
            CreateFixedCostSheet(
                date: currentDate,
                currencyCode: project?.currencyCode ?? "EUR",
                onCancel: { showsFixedCostSheet = false },
                onSave: addFixedCost
            )
        }
        .alert(item: $actionFailure) { failure in
            Alert(
                title: Text("Workflow Action Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ToolbarContentBuilder
    private var projectToolbar: some ToolbarContent {
        ToolbarItemGroup {
            bucketActionsMenu
            ControlGroup {
                editBucketButton
                markReadyButton
            }
        }
    }

    private var editBucketButton: some View {
        Button {
            showsEditBucket = true
        } label: {
            Label("Edit Bucket", systemImage: "pencil")
        }
        .disabled(project == nil || selectedBucket == nil)
        .help("Edit selected bucket")
        .tint(PikaColor.textPrimary)
    }

    private var markReadyButton: some View {
        Button {
            markSelectedBucketReady()
        } label: {
            Label("Mark Ready", systemImage: "checkmark.circle")
        }
        .disabled(!canMarkSelectedBucketReady)
        .help("Mark the selected bucket ready for invoicing")
        .tint(PikaColor.success)
    }

    private var bucketActionsMenu: some View {
        Menu {
            if let invoiceRow = selectedInvoiceRow {
                Button {
                    markInvoiceSent(invoiceRow)
                } label: {
                    Label("Mark Sent", systemImage: "paperplane")
                }
                .disabled(!invoiceRow.canMarkSent)
                .tint(PikaColor.actionAccent)

                Button {
                    markInvoicePaid(invoiceRow)
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.seal")
                }
                .disabled(!invoiceRow.canMarkPaid)
                .tint(PikaColor.success)

                Button(role: .destructive) {
                    cancelInvoice(invoiceRow)
                } label: {
                    Label("Cancel Invoice", systemImage: "xmark.circle")
                }
                .disabled(!invoiceRow.canCancel)

                Divider()
            }

            Button {
                if selectedBucket?.status == .archived {
                    restoreSelectedBucket()
                } else {
                    showsArchiveBucketConfirmation = true
                }
            } label: {
                Label(
                    selectedBucket?.status == .archived ? "Restore Bucket" : "Archive Bucket",
                    systemImage: selectedBucket?.status == .archived ? "arrow.uturn.backward" : "archivebox"
                )
            }
            .disabled(!canArchiveOrRestoreSelectedBucket)
            .tint(selectedBucket?.status == .archived ? PikaColor.success : PikaColor.warning)

            if selectedBucket?.status == .archived {
                Divider()

                Button(role: .destructive) {
                    prepareRemoveSelectedBucket()
                } label: {
                    Label("Remove Bucket", systemImage: "trash")
                }
                .disabled(!canRemoveSelectedBucket)
            }
        } label: {
            Label("Bucket Actions", systemImage: "ellipsis.circle")
        }
        .help("Bucket actions")
        .tint(PikaColor.textPrimary)
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
            .filter { invoice in
                let invoiceProjectName = invoice.projectName.isEmpty ? project.name : invoice.projectName
                return invoiceProjectName == project.name && invoice.bucketName == projection.selectedBucket.name
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
            billingAddress: workspaceStore.workspace.clients.first { $0.name == invoice.clientName }?.billingAddress ?? "",
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

    private func markSelectedBucketReady() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.markBucketReady(projectID: project.id, bucketID: bucketID)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func updateSelectedBucket(_ draft: WorkspaceBucketDraft) {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.updateBucket(projectID: project.id, bucketID: bucketID, draft)
            showsEditBucket = false
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func archiveProject() {
        guard let project else { return }

        do {
            try workspaceStore.archiveProject(projectID: project.id)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func archiveSelectedBucket() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.archiveBucket(projectID: project.id, bucketID: bucketID)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func restoreSelectedBucket() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.restoreBucket(projectID: project.id, bucketID: bucketID)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
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
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func restoreProject() {
        guard let project else { return }

        do {
            try workspaceStore.restoreProject(projectID: project.id)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
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
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
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
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
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
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
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
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
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
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func finalizeInvoice(
        presentation: InvoiceDraftPresentation,
        draft: InvoiceFinalizationDraft
    ) {
        do {
            try workspaceStore.finalizeInvoice(
                projectID: presentation.projectID,
                bucketID: presentation.bucketID,
                draft: draft
            )
            invoiceDraft = nil
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func markInvoiceSent(_ row: WorkspaceInvoiceRowProjection) {
        do {
            try workspaceStore.markInvoiceSent(invoiceID: row.id)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func markInvoicePaid(_ row: WorkspaceInvoiceRowProjection) {
        do {
            try workspaceStore.markInvoicePaid(invoiceID: row.id)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func cancelInvoice(_ row: WorkspaceInvoiceRowProjection) {
        do {
            try workspaceStore.cancelInvoice(invoiceID: row.id)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func openInvoicePDF(_ row: WorkspaceInvoiceRowProjection) {
        performInvoicePDFAction("open") {
            let rendered = try renderInvoicePDF(row)
            let url = try writeTemporaryPDF(rendered)

            #if os(macOS)
            guard NSWorkspace.shared.open(url) else {
                throw ProjectInvoiceActionError.openFailed
            }
            AppTelemetry.invoicePDFOpened(invoiceNumber: rendered.metadata.invoiceNumber)
            #else
            throw ProjectInvoiceActionError.unsupportedPlatform
            #endif
        }
    }

    private func exportInvoicePDF(_ row: WorkspaceInvoiceRowProjection) {
        performInvoicePDFAction("export") {
            let rendered = try renderInvoicePDF(row)

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
            throw ProjectInvoiceActionError.unsupportedPlatform
            #endif
        }
    }

    private func renderInvoicePDF(_ row: WorkspaceInvoiceRowProjection) throws -> InvoicePDFService.RenderedInvoice {
        try invoicePDFService.renderInvoice(
            profile: row.businessProfile ?? workspaceStore.workspace.businessProfile,
            row: row
        )
    }

    private func performInvoicePDFAction(_ action: String, operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            let message = error.localizedDescription
            actionFailure = WorkflowActionFailure(message: message)
            AppTelemetry.invoicePDFActionFailed(action: action, message: message)
        }
    }

    private func writeTemporaryPDF(_ rendered: InvoicePDFService.RenderedInvoice) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Pika", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(rendered.metadata.suggestedFilename)
        try rendered.data.write(to: url, options: .atomic)
        return url
    }
}

private extension WorkspaceInvoiceRowProjection {
    var canMarkSent: Bool {
        status == .finalized
    }

    var canMarkPaid: Bool {
        status == .finalized || status == .sent
    }

    var canCancel: Bool {
        status == .finalized || status == .sent
    }
}

private struct WorkflowActionFailure: Identifiable {
    let id = UUID()
    let message: String
}

private enum ProjectInvoiceActionError: LocalizedError {
    case openFailed
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .openFailed:
            return "The invoice PDF could not be opened."
        case .unsupportedPlatform:
            return "This invoice action is only available on Mac."
        }
    }
}

private struct InvoiceDraftPresentation: Identifiable {
    let id = UUID()
    let projectID: WorkspaceProject.ID
    let bucketID: WorkspaceBucket.ID
    let draft: InvoiceFinalizationDraft
    let totalLabel: String
    let lineItems: [WorkspaceBucketLineItemProjection]
}

private struct CreateBucketSheet: View {
    let defaultRateMinorUnits: Int
    let currencyCode: String
    let initialName: String
    let saveLabel: String
    let saveSystemImage: String
    let onCancel: () -> Void
    let onSave: (WorkspaceBucketDraft) -> Void

    @State private var name: String
    @State private var hourlyRate: Double

    init(
        defaultRateMinorUnits: Int,
        currencyCode: String,
        initialName: String = "",
        saveLabel: String = "Create Bucket",
        saveSystemImage: String = "tray.full",
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceBucketDraft) -> Void
    ) {
        self.defaultRateMinorUnits = defaultRateMinorUnits
        self.currencyCode = currencyCode
        self.initialName = initialName
        self.saveLabel = saveLabel
        self.saveSystemImage = saveSystemImage
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _hourlyRate = State(initialValue: Double(defaultRateMinorUnits) / 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Bucket") {
                    TextField("Bucket name", text: $name)
                    CurrencyAmountField("Hourly rate", value: $hourlyRate, currencyCode: currencyCode)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.pikaAction(.destructive))

                Spacer()

                Button {
                    onSave(WorkspaceBucketDraft(
                        name: name,
                        hourlyRateMinorUnits: max(Int((hourlyRate * 100).rounded()), 0)
                    ))
                } label: {
                    Label(saveLabel, systemImage: saveSystemImage)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 260)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hourlyRate > 0
    }
}

private struct CreateFixedCostSheet: View {
    let date: Date
    let currencyCode: String
    let onCancel: () -> Void
    let onSave: (WorkspaceFixedCostDraft) -> Void

    @State private var description = ""
    @State private var amount = 50.0

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Fixed cost") {
                    DatePicker("Date", selection: .constant(date), displayedComponents: .date)
                        .disabled(true)
                    TextField("Description", text: $description)
                    CurrencyAmountField("Amount", value: $amount, currencyCode: currencyCode)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.pikaAction(.destructive))

                Spacer()

                Button {
                    onSave(WorkspaceFixedCostDraft(
                        date: date,
                        description: description,
                        amountMinorUnits: max(Int((amount * 100).rounded()), 0)
                    ))
                } label: {
                    Label("Add Cost", systemImage: "plus.square")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
    }

    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }
}

private struct CreateInvoiceConfirmationSheet: View {
    let presentation: InvoiceDraftPresentation
    let onCancel: () -> Void
    let onSave: (InvoiceFinalizationDraft) -> Void
    @State private var draft: InvoiceFinalizationDraft

    init(
        presentation: InvoiceDraftPresentation,
        onCancel: @escaping () -> Void,
        onSave: @escaping (InvoiceFinalizationDraft) -> Void
    ) {
        self.presentation = presentation
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: presentation.draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Recipient") {
                    TextField("Name", text: $draft.recipientName)
                    TextField("Email", text: $draft.recipientEmail)
                    TextField("Billing address", text: $draft.recipientBillingAddress, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Invoice") {
                    TextField("Invoice number", text: $draft.invoiceNumber)
                    DatePicker("Issue date", selection: $draft.issueDate, displayedComponents: .date)
                    DatePicker("Due date", selection: $draft.dueDate, displayedComponents: .date)
                    CurrencyCodeField("Currency", text: $draft.currencyCode)
                    TextField("Note", text: $draft.note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Totals") {
                    ForEach(presentation.lineItems) { item in
                        HStack {
                            Text(item.description)
                            Spacer()
                            Text(item.quantity)
                                .foregroundStyle(PikaColor.textSecondary)
                            Text(item.amountLabel)
                                .monospacedDigit()
                                .frame(width: 120, alignment: .trailing)
                        }
                    }

                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(presentation.totalLabel)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.pikaAction(.destructive))

                Spacer()

                Button {
                    onSave(draft)
                } label: {
                    Label("Save as finalized", systemImage: "checkmark.circle")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(draft.invoiceNumber.isEmpty || draft.recipientName.isEmpty)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620)
    }
}
