import SwiftUI

struct ProjectPlaceholderView: View {
    let project: WorkspaceProject?
    let workspaceStore: WorkspaceStore
    let currentDate: Date
    @State private var selectedBucketID: WorkspaceBucket.ID?
    @State private var invoiceDraft: InvoiceDraftPresentation?
    @State private var actionFailure: WorkflowActionFailure?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

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

                HStack(spacing: 0) {
                    ProjectBucketColumn(
                        project: project,
                        projection: projection,
                        selectedBucketID: activeBucketID,
                        onSelect: { bucketID in
                            selectedBucketID = bucketID
                            AppTelemetry.projectBucketSelected(projectName: project.name)
                        }
                    )

                    BucketDetailWorkbench(
                        projection: projection,
                        draftDate: currentDate,
                        onAddEntry: { draft in
                            addTimeEntry(
                                projectID: project.id,
                                bucketID: projection.selectedBucket.id,
                                draft: draft
                            )
                        },
                        onCreateInvoice: {
                            prepareInvoiceDraft(
                                projectID: project.id,
                                bucketID: projection.selectedBucket.id,
                                totalLabel: projection.totalLabel,
                                lineItems: projection.lineItems
                            )
                        }
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
            } label: {
                Label("New Bucket", systemImage: "plus")
            }
            .disabled(true)
            .help("Bucket creation lands in a later task")

            Button {
                markSelectedBucketReady()
            } label: {
                Label("Mark Ready", systemImage: "checkmark.circle")
            }
            .disabled(!canMarkSelectedBucketReady)
            .help("Mark the selected bucket ready for invoicing")
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

    private var canMarkSelectedBucketReady: Bool {
        guard let selectedBucket else { return false }
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
}

private struct WorkflowActionFailure: Identifiable {
    let id = UUID()
    let message: String
}

private struct InvoiceDraftPresentation: Identifiable {
    let id = UUID()
    let projectID: WorkspaceProject.ID
    let bucketID: WorkspaceBucket.ID
    let draft: InvoiceFinalizationDraft
    let totalLabel: String
    let lineItems: [WorkspaceBucketLineItemProjection]
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
