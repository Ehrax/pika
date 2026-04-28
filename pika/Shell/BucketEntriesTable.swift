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
    let onDeleteEntry: (WorkspaceBucketEntryRowProjection) -> Void

    @State private var selectedRowID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: PikaSpacing.lg) {
                if showsInlineEditor {
                    Button {
                        onAddFixedCost()
                    } label: {
                        Label("Fixed Cost", systemImage: "plus.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Add a fixed cost")
                    .tint(PikaColor.actionAccent)
                }

                if let selectedRow, canDeleteRows {
                    Button(role: .destructive) {
                        delete(selectedRow)
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete selected entry")
                    .tint(PikaColor.danger)
                }

                Spacer(minLength: 0)
            }
            .font(PikaTypography.entryHelper)
            .padding(.bottom, PikaSpacing.xs)

            VStack(spacing: 0) {
                BucketEntriesHeaderRow()

                ForEach(projection.entryRows) { row in
                    SwipeToDeleteEntryRow(
                        row: row,
                        isSelected: selectedRowID == row.id,
                        canDelete: canDeleteRows,
                        onSelect: {
                            selectedRowID = row.id
                        },
                        onDelete: {
                            delete(row)
                        }
                    )

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
            .pikaDeleteCommand {
                if let selectedRow, canDeleteRows {
                    delete(selectedRow)
                }
            }
            .onChange(of: projection.entryRows.map(\.id)) { _, rowIDs in
                if let selectedRowID, !rowIDs.contains(selectedRowID) {
                    self.selectedRowID = nil
                }
            }
        }
    }

    private var canDeleteRows: Bool {
        !projection.selectedBucket.status.isInvoiceLocked
    }

    private var selectedRow: WorkspaceBucketEntryRowProjection? {
        projection.entryRows.first { $0.id == selectedRowID }
    }

    private func delete(_ row: WorkspaceBucketEntryRowProjection) {
        selectedRowID = nil
        onDeleteEntry(row)
    }
}

private extension View {
    @ViewBuilder
    func pikaDeleteCommand(perform action: (() -> Void)?) -> some View {
        #if os(macOS)
        onDeleteCommand(perform: action)
        #else
        self
        #endif
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

private struct SwipeToDeleteEntryRow: View {
    let row: WorkspaceBucketEntryRowProjection
    let isSelected: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let deleteThreshold: CGFloat = 96
    private let maximumVisibleOffset: CGFloat = 28

    var body: some View {
        BucketEntryRow(row: row, isSelected: isSelected)
            .offset(x: currentOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .contextMenu {
                if canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                }
            }
            .gesture(swipeGesture)
    }

    private var currentOffset: CGFloat {
        min(0, max(-maximumVisibleOffset, dragOffset / 3))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                guard canDelete, abs(value.translation.width) > abs(value.translation.height) else { return }
                state = min(0, value.translation.width)
            }
            .onEnded { value in
                guard canDelete, abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width <= -deleteThreshold {
                    onDelete()
                }
            }
    }
}

private struct BucketEntryRow: View {
    let row: WorkspaceBucketEntryRowProjection
    let isSelected: Bool

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
        .foregroundStyle(rowForeground)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? PikaColor.actionAccentMuted : PikaColor.surface)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: PikaRadius.sm, style: .continuous)
                    .stroke(PikaColor.actionAccent.opacity(0.34), lineWidth: 1)
            }
        }
    }

    private var rowForeground: Color {
        if isSelected {
            PikaColor.actionAccent
        } else if row.isBillable {
            PikaColor.textPrimary
        } else {
            PikaColor.textMuted
        }
    }
}
