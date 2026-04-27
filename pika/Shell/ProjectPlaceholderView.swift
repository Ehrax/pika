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
    @State private var showsArchiveConfirmation = false
    @State private var showsEditProject = false

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
            if
                let project,
                let projection = project.detailProjection(
                    selectedBucketID: selectedBucketID,
                    formatter: formatter
                )
            {
                let activeBucketID = project.normalizedBucketID(selectedBucketID) ?? projection.selectedBucket.id

                ResizableDetailSplitView {
                    ProjectBucketColumn(
                        project: project,
                        projection: projection,
                        selectedBucketID: activeBucketID,
                        onSelect: { bucketID in
                            selectedBucketID = bucketID
                            AppTelemetry.projectBucketSelected(projectName: project.name)
                        },
                        onCreateBucket: { showsCreateBucket = true }
                    )
                } detail: {
                    BucketDetailWorkbench(
                        projection: projection,
                        draftDate: currentDate,
                        invoiceRow: invoiceRow(for: projection, in: project),
                        onAddEntry: { draft in
                            addTimeEntry(
                                projectID: project.id,
                                bucketID: projection.selectedBucket.id,
                                draft: draft
                            )
                        },
                        onAddFixedCost: { showsFixedCostSheet = true },
                        onCreateInvoice: {
                            prepareInvoiceDraft(
                                projectID: project.id,
                                bucketID: projection.selectedBucket.id,
                                totalLabel: projection.totalLabel,
                                lineItems: projection.lineItems
                            )
                        },
                        onOpenInvoicePDF: openInvoicePDF,
                        onExportInvoicePDF: exportInvoicePDF,
                        onMarkInvoiceSent: markInvoiceSent,
                        onMarkInvoicePaid: markInvoicePaid,
                        onCancelInvoice: cancelInvoice
                    )
                }
                .background(PikaColor.background)
                .onAppear {
                    selectedBucketID = activeBucketID
                    AppTelemetry.projectDetailLoaded(projectName: project.name, bucketCount: projection.bucketRows.count)
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
        .navigationTitle(project?.name ?? "Project")
        .toolbar {
            Button {
                showsCreateBucket = true
            } label: {
                Label("New Bucket", systemImage: "plus")
            }
            .disabled(project == nil || project?.isArchived == true)
            .help("Create a bucket")

            Button {
                markSelectedBucketReady()
            } label: {
                Label("Mark Ready", systemImage: "checkmark.circle")
            }
            .disabled(!canMarkSelectedBucketReady)
            .help("Mark the selected bucket ready for invoicing")

            Menu {
                Button {
                    showsEditProject = true
                } label: {
                    Label("Edit Project", systemImage: "pencil")
                }
                .disabled(project == nil)

                Divider()

                Button {
                    if project?.isArchived == true {
                        restoreProject()
                    } else {
                        showsArchiveConfirmation = true
                    }
                } label: {
                    Label(
                        project?.isArchived == true ? "Restore Project" : "Archive Project",
                        systemImage: project?.isArchived == true ? "arrow.uturn.backward" : "archivebox"
                    )
                }
                .disabled(project == nil)
            } label: {
                Label("Project Actions", systemImage: "ellipsis.circle")
            }
            .help("Project actions")
        }
        .confirmationDialog(
            "Archive this project?",
            isPresented: $showsArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Project", role: .destructive) {
                archiveProject()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived projects are hidden from the active project list, but invoices and history stay available.")
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
        .sheet(isPresented: $showsEditProject) {
            if let project {
                ProjectEditorSheet(
                    project: project,
                    clients: workspaceStore.workspace.clients,
                    onCancel: { showsEditProject = false },
                    onSave: updateProject
                )
            }
        }
        .sheet(isPresented: $showsCreateBucket) {
            CreateBucketSheet(
                defaultRateMinorUnits: selectedBucket?.hourlyRateMinorUnits ?? 8_000,
                onCancel: { showsCreateBucket = false },
                onSave: createBucket
            )
        }
        .sheet(isPresented: $showsFixedCostSheet) {
            CreateFixedCostSheet(
                date: currentDate,
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

    private var selectedBucket: WorkspaceBucket? {
        guard let project else { return nil }
        let bucketID = project.normalizedBucketID(selectedBucketID)
        return project.buckets.first { $0.id == bucketID }
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

    private func markSelectedBucketReady() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.markBucketReady(projectID: project.id, bucketID: bucketID)
        } catch {
            actionFailure = WorkflowActionFailure(message: error.localizedDescription)
        }
    }

    private func updateProject(_ draft: WorkspaceProjectUpdateDraft) {
        guard let project else { return }

        do {
            try workspaceStore.updateProject(projectID: project.id, draft)
            showsEditProject = false
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
    let onCancel: () -> Void
    let onSave: (WorkspaceBucketDraft) -> Void

    @State private var name = ""
    @State private var hourlyRate: Double

    init(
        defaultRateMinorUnits: Int,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceBucketDraft) -> Void
    ) {
        self.defaultRateMinorUnits = defaultRateMinorUnits
        self.onCancel = onCancel
        self.onSave = onSave
        _hourlyRate = State(initialValue: Double(defaultRateMinorUnits) / 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Bucket") {
                    TextField("Bucket name", text: $name)
                    TextField("Hourly rate", value: $hourlyRate, format: .number.precision(.fractionLength(0...2)))
                        .monospacedDigit()
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onSave(WorkspaceBucketDraft(
                        name: name,
                        hourlyRateMinorUnits: max(Int((hourlyRate * 100).rounded()), 0)
                    ))
                } label: {
                    Label("Create Bucket", systemImage: "tray.full")
                }
                .keyboardShortcut(.defaultAction)
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
                    TextField("Amount", value: $amount, format: .number.precision(.fractionLength(0...2)))
                        .monospacedDigit()
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

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
                    TextField("Currency", text: $draft.currencyCode)
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
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onSave(draft)
                } label: {
                    Label("Save as finalized", systemImage: "checkmark.circle")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.invoiceNumber.isEmpty || draft.recipientName.isEmpty)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620)
    }
}
