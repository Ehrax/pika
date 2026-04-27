import SwiftUI

struct BucketDetailWorkbench: View {
    let projection: WorkspaceBucketDetailProjection
    let draftDate: Date
    let onAddEntry: (WorkspaceTimeEntryDraft) -> Void
    let onAddFixedCost: () -> Void
    let onCreateInvoice: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                BucketWorkbenchHeader(projection: projection)

                if projection.selectedBucket.status == .ready {
                    ReadyBucketSummary(
                        projection: projection,
                        onCreateInvoice: onCreateInvoice
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
