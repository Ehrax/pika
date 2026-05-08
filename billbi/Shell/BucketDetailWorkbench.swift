import SwiftUI

struct BucketDetailWorkbench: View {
    let projection: WorkspaceBucketDetailProjection
    let draftDate: Date
    let invoiceRow: WorkspaceInvoiceRowProjection?
    let canMarkReady: Bool
    let onAddEntry: (WorkspaceTimeEntryDraft) -> Void
    let onAddFixedCost: () -> Void
    let onDeleteEntry: (WorkspaceBucketEntryRowProjection) -> Void
    let onUpdateEntryDate: (WorkspaceBucketEntryRowProjection, Date) -> Void
    let onMarkReady: () -> Void
    let onCreateInvoice: () -> Void
    let canOpenInvoicePDF: Bool
    let onOpenInvoicePDF: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                BucketWorkbenchHeader(projection: projection)

                if projection.selectedBucket.status == .open {
                    ActiveBucketSummary(
                        projection: projection,
                        canMarkReady: canMarkReady,
                        onMarkReady: onMarkReady
                    )
                } else if projection.selectedBucket.status == .ready {
                    ReadyBucketSummary(
                        projection: projection,
                        onCreateInvoice: onCreateInvoice
                    )
                } else if let invoiceRow {
                    InvoiceBucketSummary(
                        projection: projection,
                        invoiceRow: invoiceRow,
                        canOpenPDF: canOpenInvoicePDF,
                        onOpenPDF: onOpenInvoicePDF
                    )
                }

                BucketEntriesTable(
                    projection: projection,
                    draftDate: draftDate,
                    showsInlineEditor: !projection.selectedBucket.status.isInvoiceLocked,
                    onAddFixedCost: onAddFixedCost,
                    onAddEntry: onAddEntry,
                    onDeleteEntry: onDeleteEntry,
                    onUpdateEntryDate: onUpdateEntryDate
                )
            }
            .padding(.horizontal, BillbiSpacing.xl + BillbiSpacing.md)
            .padding(.vertical, BillbiSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BillbiColor.background)
    }
}

private struct BucketWorkbenchHeader: View {
    let projection: WorkspaceBucketDetailProjection

    var body: some View {
        HStack(alignment: .top, spacing: BillbiSpacing.lg) {
            VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                Text(projection.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(BillbiColor.textPrimary)

                HStack(spacing: BillbiSpacing.sm) {
                    Text(projection.projectName)
                    DotSeparator()
                    Text(projection.clientName)
                    DotSeparator()
                    Text("rate \(projection.rateLabel)")
                        .monospacedDigit()
                }
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(projection.totalLabel)
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(BillbiColor.textPrimary)
            }
        }
    }
}

private struct DotSeparator: View {
    var body: some View {
        Circle()
            .fill(BillbiColor.textMuted)
            .frame(width: 3, height: 3)
    }
}

private struct InvoiceBucketSummary: View {
    let projection: WorkspaceBucketDetailProjection
    let invoiceRow: WorkspaceInvoiceRowProjection
    let canOpenPDF: Bool
    let onOpenPDF: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: BillbiSpacing.lg) {
            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                HStack(spacing: BillbiSpacing.sm) {
                    Text("Invoice")
                        .font(BillbiTypography.micro)
                        .foregroundStyle(.white.opacity(0.72))
                        .textCase(.uppercase)

                    StatusBadge(invoiceRow.statusTone, title: invoiceRow.statusTitle)
                }

                Text(invoiceRow.number)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)

                Text("\(projection.totalLabel) · due \(invoiceRow.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(BillbiTypography.small)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                onOpenPDF()
            } label: {
                Label("Open PDF", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(InvoicePreviewIconButtonStyle())
            .disabled(!canOpenPDF)
            .help("Open the selected invoice PDF")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BillbiSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md))
    }
}

private struct InvoicePreviewIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(BillbiColor.brand.opacity(isEnabled ? 1 : 0.38))
            .frame(width: 36, height: 36)
            .background(BillbiColor.brand.opacity(isEnabled ? 0.12 : 0.05))
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(BillbiColor.brand.opacity(isEnabled ? 0.32 : 0.12), lineWidth: 1)
            }
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct ActiveBucketSummary: View {
    let projection: WorkspaceBucketDetailProjection
    let canMarkReady: Bool
    let onMarkReady: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: BillbiSpacing.lg) {
            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                Text("Active bucket")
                    .font(BillbiTypography.micro)
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)
                Text(projection.totalLabel)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(projection.billableSummary) · \(projection.fixedCostLabel) · \(projection.nonBillableSummary)")
                    .font(BillbiTypography.small)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                onMarkReady()
            } label: {
                Label("Mark Ready", systemImage: "checkmark.circle")
            }
            .buttonStyle(.billbiAction(.success))
            .disabled(!canMarkReady)
            .help(canMarkReady ? "Mark ready for invoicing" : "Add billable value before invoicing")
        }
        .padding(BillbiSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md))
    }
}

private struct InvoiceBucketActions: View {
    let onOpenPDF: () -> Void
    let onExportPDF: () -> Void

    var body: some View {
        HStack(spacing: BillbiSpacing.xs) {
            Button {
                onOpenPDF()
            } label: {
                Label("Open PDF", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.billbiAction(.neutral))

            Button {
                onExportPDF()
            } label: {
                Label("Export", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.billbiAction(.neutral))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension WorkspaceInvoiceRowProjection {
    var statusTone: BillbiStatusTone {
        InvoiceWorkflowPolicy.statusTone(status: status, isOverdue: isOverdue)
    }
}

private struct ReadyBucketSummary: View {
    let projection: WorkspaceBucketDetailProjection
    let onCreateInvoice: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: BillbiSpacing.lg) {
            VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
                Text("Ready to invoice")
                    .font(BillbiTypography.micro)
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)
                Text(projection.totalLabel)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(projection.billableSummary) · \(projection.fixedCostLabel) · \(projection.nonBillableSummary)")
                    .font(BillbiTypography.small)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Button {
                onCreateInvoice()
            } label: {
                Label("Create Invoice", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.billbiAction(.primary))
        }
        .padding(BillbiSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md))
    }
}
