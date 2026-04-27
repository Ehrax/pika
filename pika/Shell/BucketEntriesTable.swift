import SwiftUI

enum BucketEntriesLayout {
    static let dateWidth: CGFloat = 70
    static let timeWidth: CGFloat = 142
    static let hoursWidth: CGFloat = 60
    static let amountWidth: CGFloat = 92
    static let inputHeight: CGFloat = 26
}

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
                .frame(width: BucketEntriesLayout.dateWidth, alignment: .leading)
            Text("Time")
                .frame(width: BucketEntriesLayout.timeWidth, alignment: .leading)
            Text("Description")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Hrs")
                .frame(width: BucketEntriesLayout.hoursWidth, alignment: .trailing)
            Text("Amount")
                .frame(width: BucketEntriesLayout.amountWidth, alignment: .trailing)
        }
        .font(PikaTypography.entry.weight(.medium))
        .foregroundStyle(PikaColor.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, 8)
        .background(PikaColor.surfaceAlt)
    }
}

private struct BucketEntryRow: View {
    let row: WorkspaceBucketEntryRowProjection

    var body: some View {
        HStack(spacing: PikaSpacing.md) {
            Text(row.dateLabel)
                .monospacedDigit()
                .frame(width: BucketEntriesLayout.dateWidth, alignment: .leading)
                .foregroundStyle(PikaColor.textSecondary)
            Text(row.timeLabel)
                .monospacedDigit()
                .frame(width: BucketEntriesLayout.timeWidth, alignment: .leading)
            Text(row.description)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.hoursLabel)
                .monospacedDigit()
                .frame(width: BucketEntriesLayout.hoursWidth, alignment: .trailing)
            Text(row.amountLabel)
                .monospacedDigit()
                .fontWeight(row.isBillable ? .medium : .regular)
                .frame(width: BucketEntriesLayout.amountWidth, alignment: .trailing)
        }
        .font(PikaTypography.entry)
        .foregroundStyle(row.isBillable ? PikaColor.textPrimary : PikaColor.textMuted)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, 10)
    }
}
