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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
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
                        invoiceRow: invoiceRow
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
            .padding(.horizontal, PikaSpacing.xl + PikaSpacing.md)
            .padding(.vertical, PikaSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PikaColor.background)
    }
}

private struct BucketWorkbenchHeader: View {
    let projection: WorkspaceBucketDetailProjection

    var body: some View {
        HStack(alignment: .top, spacing: PikaSpacing.lg) {
            VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                Text(projection.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(PikaColor.textPrimary)

                HStack(spacing: PikaSpacing.sm) {
                    Text(projection.projectName)
                    DotSeparator()
                    Text(projection.clientName)
                    DotSeparator()
                    Text("rate \(projection.rateLabel)")
                        .monospacedDigit()
                }
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(projection.totalLabel)
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PikaColor.textPrimary)
            }
        }
    }
}

private struct DotSeparator: View {
    var body: some View {
        Circle()
            .fill(PikaColor.textMuted)
            .frame(width: 3, height: 3)
    }
}

private struct InvoiceBucketSummary: View {
    let projection: WorkspaceBucketDetailProjection
    let invoiceRow: WorkspaceInvoiceRowProjection

    var body: some View {
        HStack(alignment: .top, spacing: PikaSpacing.lg) {
            VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                HStack(spacing: PikaSpacing.sm) {
                    Text("Invoice")
                        .font(PikaTypography.micro)
                        .foregroundStyle(.white.opacity(0.72))
                        .textCase(.uppercase)

                    StatusBadge(invoiceRow.statusTone, title: invoiceRow.statusTitle)
                }

                Text(invoiceRow.number)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)

                Text("\(projection.totalLabel) · due \(invoiceRow.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(PikaTypography.small)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PikaSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
    }
}

private struct ActiveBucketSummary: View {
    let projection: WorkspaceBucketDetailProjection
    let canMarkReady: Bool
    let onMarkReady: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: PikaSpacing.lg) {
            VStack(alignment: .leading, spacing: PikaSpacing.xs) {
                Text("Active bucket")
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
                onMarkReady()
            } label: {
                Label("Mark Ready", systemImage: "checkmark.circle")
            }
            .buttonStyle(.pikaAction(.success))
            .disabled(!canMarkReady)
            .help(canMarkReady ? "Mark ready for invoicing" : "Add billable value before invoicing")
        }
        .padding(PikaSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
    }
}

private extension WorkspaceInvoiceRowProjection {
    var statusTone: PikaStatusTone {
        InvoiceWorkflowPolicy.statusTone(status: status, isOverdue: isOverdue)
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
            .buttonStyle(.pikaAction(.primary))
        }
        .padding(PikaSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
    }
}
