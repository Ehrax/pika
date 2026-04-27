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
                    BucketColumn(
                        project: project,
                        projection: projection,
                        selectedBucketID: activeBucketID,
                        onSelect: { bucketID in
                            selectedBucketID = bucketID
                            AppTelemetry.projectBucketSelected(projectName: project.name)
                        }
                    )

                    BucketDetailPane(
                        projection: projection,
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
        return selectedBucket.status == .open && selectedBucket.totalMinorUnits > 0
    }

    private func markSelectedBucketReady() {
        guard let project, let bucketID = project.normalizedBucketID(selectedBucketID) else { return }

        do {
            try workspaceStore.markBucketReady(projectID: project.id, bucketID: bucketID)
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

private struct BucketColumn: View {
    let project: WorkspaceProject
    let projection: WorkspaceBucketDetailProjection
    let selectedBucketID: WorkspaceBucket.ID
    let onSelect: (WorkspaceBucket.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Buckets")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)
                    Text(project.clientName)
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(true)
                .help("Bucket creation lands in a later task")
            }
            .padding(.horizontal, PikaSpacing.md)
            .padding(.vertical, PikaSpacing.md)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(projection.bucketRows) { row in
                        Button {
                            onSelect(row.id)
                        } label: {
                            BucketRow(row: row, isSelected: row.id == selectedBucketID)
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
        .frame(width: 260)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(PikaColor.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PikaColor.border)
                .frame(width: 1)
        }
    }
}

private struct BucketRow: View {
    let row: WorkspaceBucketRowProjection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            Image(systemName: row.status == .finalized ? "doc.text.fill" : "diamond")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(PikaTypography.body.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(PikaColor.textPrimary)
                    .lineLimit(1)
                Text(row.meta)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PikaColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: PikaSpacing.sm)

            if let statusTitle = row.statusTitle {
                StatusBadge(row.status.pikaTone, title: statusTitle)
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

private extension BucketStatus {
    var pikaTone: PikaStatusTone {
        switch self {
        case .open:
            .neutral
        case .ready:
            .success
        case .finalized:
            .warning
        case .archived:
            .neutral
        }
    }
}

private struct BucketDetailPane: View {
    let projection: WorkspaceBucketDetailProjection
    let onCreateInvoice: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                BucketHeader(projection: projection)

                if projection.selectedBucket.status == .ready {
                    ReadyBucketSummary(
                        projection: projection,
                        onCreateInvoice: onCreateInvoice
                    )
                }

                HStack(spacing: PikaSpacing.md) {
                    SummaryTile(title: "Billable", value: projection.billableSummary)
                    SummaryTile(title: "Non-billable", value: projection.nonBillableSummary)
                    SummaryTile(title: "Fixed costs", value: projection.fixedCostLabel)
                }

                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    SectionHeader(title: "Entries and costs", detail: "\(projection.lineItems.count) rows")
                    BucketEntriesTable(lineItems: projection.lineItems)
                }
            }
            .padding(.horizontal, PikaSpacing.xl)
            .padding(.vertical, PikaSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PikaColor.background)
    }
}

private struct ReadyBucketSummary: View {
    let projection: WorkspaceBucketDetailProjection
    let onCreateInvoice: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: PikaSpacing.lg) {
            VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                Text("Ready to invoice")
                    .font(PikaTypography.micro)
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)
                Text(projection.totalLabel)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(projection.billableSummary) · \(projection.fixedCostLabel) · \(projection.nonBillableSummary)")
                    .font(PikaTypography.small)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                onCreateInvoice()
            } label: {
                Label("Create Invoice", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(PikaSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.lg))
    }
}

private struct BucketHeader: View {
    let projection: WorkspaceBucketDetailProjection

    var body: some View {
        HStack(alignment: .top, spacing: PikaSpacing.lg) {
            VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                Text(projection.title)
                    .font(PikaTypography.display)
                    .foregroundStyle(PikaColor.textPrimary)

                HStack(spacing: PikaSpacing.sm) {
                    Text(projection.projectName)
                    Text("·")
                    Text(projection.clientName)
                    Text("·")
                    Text(projection.currencyCode)
                }
                .font(PikaTypography.body)
                .foregroundStyle(PikaColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(projection.totalLabel)
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PikaColor.textPrimary)
                Text("\(projection.billableSummary) · \(projection.nonBillableSummary)")
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textMuted)
            }
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.xs) {
            Text(title)
                .font(PikaTypography.micro)
                .foregroundStyle(PikaColor.textMuted)
                .textCase(.uppercase)
            Text(value)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(PikaColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PikaSpacing.md)
        .pikaSurface()
    }
}

private struct BucketEntriesTable: View {
    let lineItems: [WorkspaceBucketLineItemProjection]

    var body: some View {
        VStack(spacing: 0) {
            TableHeader()

            ForEach(lineItems) { item in
                HStack(spacing: PikaSpacing.md) {
                    Text(item.description)
                        .font(PikaTypography.body)
                        .foregroundStyle(item.isBillable ? PikaColor.textPrimary : PikaColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.quantity)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PikaColor.textSecondary)
                        .frame(width: 120, alignment: .trailing)
                    Text(item.amountLabel)
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(item.isBillable ? PikaColor.textPrimary : PikaColor.textMuted)
                        .frame(width: 120, alignment: .trailing)
                }
                .padding(.horizontal, PikaSpacing.md)
                .padding(.vertical, 12)

                if item.id != lineItems.last?.id {
                    Divider()
                        .overlay(PikaColor.border)
                }
            }
        }
        .pikaSurface()
    }
}

private struct TableHeader: View {
    var body: some View {
        HStack(spacing: PikaSpacing.md) {
            Text("Description")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Qty")
                .frame(width: 120, alignment: .trailing)
            Text("Amount")
                .frame(width: 120, alignment: .trailing)
        }
        .font(PikaTypography.micro)
        .foregroundStyle(PikaColor.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, 10)
        .background(PikaColor.surfaceAlt)
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
