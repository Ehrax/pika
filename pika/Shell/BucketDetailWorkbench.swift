import SwiftUI

struct BucketDetailWorkbench: View {
    let projection: WorkspaceBucketDetailProjection
    let draftDate: Date
    let invoiceRow: WorkspaceInvoiceRowProjection?
    let onAddEntry: (WorkspaceTimeEntryDraft) -> Void
    let onAddFixedCost: () -> Void
    let onCreateInvoice: () -> Void
    let onOpenInvoicePDF: (WorkspaceInvoiceRowProjection) -> Void
    let onExportInvoicePDF: (WorkspaceInvoiceRowProjection) -> Void
    let onMarkInvoiceSent: (WorkspaceInvoiceRowProjection) -> Void
    let onMarkInvoicePaid: (WorkspaceInvoiceRowProjection) -> Void
    let onCancelInvoice: (WorkspaceInvoiceRowProjection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                BucketWorkbenchHeader(projection: projection)

                if projection.selectedBucket.status == .ready {
                    ReadyBucketSummary(
                        projection: projection,
                        onCreateInvoice: onCreateInvoice
                    )
                } else if let invoiceRow {
                    InvoiceBucketSummary(
                        projection: projection,
                        invoiceRow: invoiceRow,
                        onOpenPDF: { onOpenInvoicePDF(invoiceRow) },
                        onExportPDF: { onExportInvoicePDF(invoiceRow) },
                        onMarkSent: { onMarkInvoiceSent(invoiceRow) },
                        onMarkPaid: { onMarkInvoicePaid(invoiceRow) },
                        onCancel: { onCancelInvoice(invoiceRow) }
                    )
                }

                BucketEntriesTable(
                    projection: projection,
                    draftDate: draftDate,
                    showsInlineEditor: !projection.selectedBucket.status.isInvoiceLocked,
                    onAddFixedCost: onAddFixedCost,
                    onAddEntry: onAddEntry
                )
            }
            .padding(.horizontal, PikaSpacing.xl)
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
                Text("\(projection.billableSummary) · \(projection.nonBillableSummary)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PikaColor.textMuted)
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
    let onOpenPDF: () -> Void
    let onExportPDF: () -> Void
    let onMarkSent: () -> Void
    let onMarkPaid: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.md) {
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

                VStack(alignment: .trailing, spacing: PikaSpacing.sm) {
                    HStack(spacing: PikaSpacing.xs) {
                        Button {
                            onOpenPDF()
                        } label: {
                            Label("Open PDF", systemImage: "doc.text.magnifyingglass")
                        }

                        Button {
                            onExportPDF()
                        } label: {
                            Label("Export", systemImage: "arrow.down.doc")
                        }
                    }

                    HStack(spacing: PikaSpacing.xs) {
                        Button {
                            onMarkSent()
                        } label: {
                            Label("Sent", systemImage: "paperplane")
                        }
                        .disabled(!canMarkSent)

                        Button {
                            onMarkPaid()
                        } label: {
                            Label("Paid", systemImage: "checkmark.seal")
                        }
                        .disabled(!canMarkPaid)

                        Button(role: .destructive) {
                            onCancel()
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                        .disabled(!canCancel)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(PikaSpacing.md)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
    }

    private var canMarkSent: Bool {
        invoiceRow.status == .finalized
    }

    private var canMarkPaid: Bool {
        invoiceRow.status == .finalized || invoiceRow.status == .sent
    }

    private var canCancel: Bool {
        invoiceRow.status == .finalized || invoiceRow.status == .sent
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
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
    }
}
