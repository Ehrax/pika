import SwiftUI

struct BucketEntriesTable: View {
    let projection: WorkspaceBucketDetailProjection
    let draftDate: Date
    let showsInlineEditor: Bool
    let onAddFixedCost: () -> Void
    let onAddEntry: (WorkspaceTimeEntryDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(
                    title: "Entries",
                    detail: showsInlineEditor
                        ? "\(projection.entryRows.count) rows + 1 draft"
                        : "\(projection.entryRows.count) rows"
                )

                if showsInlineEditor {
                    Button {
                        onAddFixedCost()
                    } label: {
                        Label("Fixed Cost", systemImage: "plus.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Add a fixed cost")
                }
            }

            VStack(spacing: 0) {
                BucketEntriesHeaderRow()

                ForEach(projection.entryRows) { row in
                    BucketEntryRow(row: row)

                    if row.id != projection.entryRows.last?.id || showsInlineEditor {
                        Divider()
                            .overlay(PikaColor.border)
                    }
                }

                if showsInlineEditor {
                    InlineEntryEditor(
                        date: draftDate,
                        hourlyRateMinorUnits: projection.selectedBucket.hourlyRateMinorUnits ?? 0,
                        onSave: onAddEntry
                    )
                }
            }
            .background(PikaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: PikaRadius.md)
                    .stroke(PikaColor.border, lineWidth: 1)
            }
        }
    }
}

private struct BucketEntriesHeaderRow: View {
    var body: some View {
        HStack(spacing: PikaSpacing.md) {
            Text("Date")
                .frame(width: 64, alignment: .leading)
            Text("Time")
                .frame(width: 110, alignment: .leading)
            Text("Description")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Hrs")
                .frame(width: 60, alignment: .trailing)
            Text("Amount")
                .frame(width: 92, alignment: .trailing)
        }
        .font(PikaTypography.micro)
        .foregroundStyle(PikaColor.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, 10)
        .background(PikaColor.surfaceAlt)
    }
}

private struct BucketEntryRow: View {
    let row: WorkspaceBucketEntryRowProjection

    var body: some View {
        HStack(spacing: PikaSpacing.md) {
            Text(row.dateLabel)
                .frame(width: 64, alignment: .leading)
                .foregroundStyle(PikaColor.textSecondary)
            Text(row.timeLabel)
                .frame(width: 110, alignment: .leading)
            Text(row.description)
                .font(PikaTypography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.hoursLabel)
                .frame(width: 60, alignment: .trailing)
            Text(row.amountLabel)
                .fontWeight(row.isBillable ? .medium : .regular)
                .frame(width: 92, alignment: .trailing)
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(row.isBillable ? PikaColor.textPrimary : PikaColor.textMuted)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, 12)
    }
}
