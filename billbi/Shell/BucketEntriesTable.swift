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
    let onUpdateEntryDate: (WorkspaceBucketEntryRowProjection, Date) -> Void

    @State private var selectedRowID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: BillbiSpacing.lg) {
                if showsInlineEditor {
                    Button {
                        onAddFixedCost()
                    } label: {
                        Label("Fixed Cost", systemImage: "plus.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Add a fixed cost")
                    .tint(BillbiColor.actionAccent)
                }

                if let selectedRow, canDeleteRows {
                    Button(role: .destructive) {
                        delete(selectedRow)
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete selected entry")
                    .tint(BillbiColor.danger)
                }

                Spacer(minLength: 0)
            }
            .font(BillbiTypography.entryHelper)
            .padding(.bottom, BillbiSpacing.xs)

            VStack(spacing: 0) {
                BucketEntriesHeaderRow()

                ForEach(projection.entryRows) { row in
                    SwipeToDeleteEntryRow(
                        row: row,
                        isSelected: selectedRowID == row.id,
                        canDelete: canDeleteRows,
                        canEditDate: canEditRows,
                        onSelect: {
                            selectedRowID = row.id
                        },
                        onDelete: {
                            delete(row)
                        },
                        onUpdateDate: { date in
                            onUpdateEntryDate(row, date)
                        }
                    )

                    if row.id != projection.entryRows.last?.id || showsInlineEditor {
                        Divider()
                            .overlay(BillbiColor.border)
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
            .background(BillbiColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.md)
                    .stroke(BillbiColor.border, lineWidth: 1)
            }
            .billbiDeleteCommand {
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

    private var canEditRows: Bool {
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
    func billbiDeleteCommand(perform action: (() -> Void)?) -> some View {
        #if os(macOS)
        onDeleteCommand(perform: action)
        #else
        self
        #endif
    }
}

private struct BucketEntriesHeaderRow: View {
    var body: some View {
        HStack(spacing: BillbiSpacing.md) {
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
        .font(BillbiTypography.entry.weight(.medium))
        .foregroundStyle(BillbiColor.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, 8)
        .background(BillbiColor.surfaceAlt)
    }
}

private struct SwipeToDeleteEntryRow: View {
    let row: WorkspaceBucketEntryRowProjection
    let isSelected: Bool
    let canDelete: Bool
    let canEditDate: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onUpdateDate: (Date) -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let deleteThreshold: CGFloat = 96
    private let maximumVisibleOffset: CGFloat = 28

    var body: some View {
        BucketEntryRow(
            row: row,
            isSelected: isSelected,
            canEditDate: canEditDate,
            onUpdateDate: onUpdateDate
        )
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
    let canEditDate: Bool
    let onUpdateDate: (Date) -> Void

    @State private var showsDatePicker = false

    var body: some View {
        HStack(spacing: BillbiSpacing.md) {
            dateCell
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
        .font(BillbiTypography.entry)
        .foregroundStyle(rowForeground)
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? BillbiColor.actionAccentMuted : BillbiColor.surface)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous)
                    .stroke(BillbiColor.actionAccentBorder, lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var dateCell: some View {
        if let date = row.date, canEditDate {
            Text(row.dateLabel)
                .monospacedDigit()
                .frame(width: BucketEntriesLayout.dateWidth, alignment: .leading)
                .foregroundStyle(BillbiColor.textSecondary)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    showsDatePicker = true
                }
                .help("Double-click to change the entry date")
                .sheet(isPresented: $showsDatePicker) {
                    EntryDatePickerSheet(
                        date: date,
                        onCancel: {
                            showsDatePicker = false
                        },
                        onSave: { selectedDate in
                            onUpdateDate(selectedDate)
                            showsDatePicker = false
                        }
                    )
                }
        } else {
            Text(row.dateLabel)
                .monospacedDigit()
                .frame(width: BucketEntriesLayout.dateWidth, alignment: .leading)
                .foregroundStyle(BillbiColor.textSecondary)
        }
    }

    private var rowForeground: Color {
        if isSelected {
            BillbiColor.actionAccent
        } else if row.isBillable {
            BillbiColor.textPrimary
        } else {
            BillbiColor.textMuted
        }
    }
}
