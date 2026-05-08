import SwiftUI

struct InlineEntryEditor: View {
    let date: Date
    let hourlyRateMinorUnits: Int
    let onSave: (WorkspaceTimeEntryDraft) -> Void

    @State private var entryDate: Date
    @State private var timeInput = "10:00-12:00"
    @State private var description = ""
    @State private var isBillable = true
    @State private var showsDatePicker = false
    @FocusState private var focusedField: Field?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    init(
        date: Date,
        hourlyRateMinorUnits: Int,
        onSave: @escaping (WorkspaceTimeEntryDraft) -> Void
    ) {
        self.date = date
        self.hourlyRateMinorUnits = hourlyRateMinorUnits
        self.onSave = onSave
        _entryDate = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: BillbiSpacing.md) {
                Text(dateLabel)
                    .font(BillbiTypography.entry.monospacedDigit())
                    .frame(width: BucketEntriesLayout.dateWidth, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        showsDatePicker = true
                    }
                    .help("Double-click to change the entry date")

                TextField("10:00-12:00", text: $timeInput)
                    .textFieldStyle(.plain)
                    .font(BillbiTypography.input.monospacedDigit())
                    .padding(.horizontal, BillbiSpacing.sm)
                    .frame(width: BucketEntriesLayout.timeWidth, height: BucketEntriesLayout.inputHeight, alignment: .leading)
                    .background(BillbiColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: BillbiRadius.sm)
                            .stroke(
                                focusedField == .time ? BillbiColor.brandBorder : BillbiColor.borderStrong,
                                lineWidth: focusedField == .time ? BillbiColor.inputFocusBorderWidth : 1
                            )
                    }
                    .focused($focusedField, equals: .time)
                    .onSubmit {
                        focusedField = .description
                    }

                TextField("what did you work on?", text: $description)
                    .textFieldStyle(.plain)
                    .font(BillbiTypography.input)
                    .padding(.horizontal, BillbiSpacing.sm)
                    .frame(maxWidth: .infinity, minHeight: BucketEntriesLayout.inputHeight, alignment: .leading)
                    .background(BillbiColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: BillbiRadius.sm)
                            .stroke(
                                focusedField == .description ? BillbiColor.brandBorder : BillbiColor.borderStrong,
                                lineWidth: focusedField == .description ? BillbiColor.inputFocusBorderWidth : 1
                            )
                    }
                    .focused($focusedField, equals: .description)
                    .onSubmit {
                        saveDraft()
                    }

                Text(draft.hoursLabel)
                    .font(BillbiTypography.entry.monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .frame(width: BucketEntriesLayout.hoursWidth, alignment: .trailing)

                Text(draft.amountLabel)
                    .font(BillbiTypography.entry.monospacedDigit().weight(.medium))
                    .foregroundStyle(BillbiColor.textMuted)
                    .frame(width: BucketEntriesLayout.amountWidth, alignment: .trailing)
            }
            .padding(.horizontal, BillbiSpacing.md)
            .padding(.vertical, 10)
            .background(BillbiColor.brandMuted)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(BillbiColor.brand)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(BillbiColor.brand)
                    .frame(height: 1)
            }

            helperLine
        }
        .sheet(isPresented: $showsDatePicker) {
            EntryDatePickerSheet(
                date: entryDate,
                onCancel: {
                    showsDatePicker = false
                },
                onSave: { selectedDate in
                    entryDate = selectedDate
                    showsDatePicker = false
                }
            )
        }
        .billbiExitCommand {
            resetDraft()
        }
    }

    private var draft: WorkspaceInlineEntryDraftProjection {
        WorkspaceInlineEntryDraftProjection(
            timeInput: timeInput,
            description: description,
            isBillable: isBillable,
            hourlyRateMinorUnits: hourlyRateMinorUnits,
            formatter: formatter
        )
    }

    private var dateLabel: String {
        entryDate.formatted(.dateTime.month(.abbreviated).day())
    }

    private var helperLine: some View {
        HStack(spacing: BillbiSpacing.sm) {
            HelperKey("tab")
            Text("next field")
            Divider()
                .frame(height: 10)
            HelperKey("return")
            Text("save")
            Divider()
                .frame(height: 10)
            HelperKey("esc")
            Text("cancel")
            Spacer()
            billableToggle
        }
        .font(BillbiTypography.entryHelper)
        .foregroundStyle(BillbiColor.textMuted)
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, BillbiSpacing.sm)
        .background(BillbiColor.surfaceAlt)
    }

    @ViewBuilder
    private var billableToggle: some View {
        #if os(macOS)
        Toggle("Billable", isOn: $isBillable)
            .toggleStyle(.checkbox)
            .font(BillbiTypography.entryHelper)
        #else
        Toggle("Billable", isOn: $isBillable)
            .font(BillbiTypography.entryHelper)
        #endif
    }

    private func resetDraft() {
        timeInput = "10:00-12:00"
        description = ""
        isBillable = true
        focusedField = nil
    }

    private func saveDraft() {
        guard draft.durationMinutes != nil,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            focusedField = description.isEmpty ? .description : .time
            return
        }

        onSave(WorkspaceTimeEntryDraft(
            date: entryDate,
            timeInput: timeInput,
            description: description,
            isBillable: isBillable
        ))
        resetDraft()
    }

    private enum Field {
        case time
        case description
    }
}

struct EntryDatePickerSheet: View {
    let onCancel: () -> Void
    let onSave: (Date) -> Void

    @State private var draftDate: Date

    init(
        date: Date,
        onCancel: @escaping () -> Void,
        onSave: @escaping (Date) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        _draftDate = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                Text("Entry date")
                    .font(BillbiTypography.subheading)
                    .foregroundStyle(BillbiColor.textPrimary)

                DatePicker("", selection: $draftDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
            }
            .padding(BillbiSpacing.md)

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.billbiAction(.destructive))

                Spacer()

                Button {
                    onSave(draftDate)
                } label: {
                    Label("Set Date", systemImage: "calendar")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.billbiAction(.primary))
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 320, idealWidth: 340, minHeight: 360)
        .background(BillbiColor.background)
    }
}

private extension View {
    @ViewBuilder
    func billbiExitCommand(perform action: (() -> Void)?) -> some View {
        #if os(macOS)
        onExitCommand(perform: action)
        #else
        self
        #endif
    }
}

private struct HelperKey: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(BillbiTypography.entryHelper.monospacedDigit())
            .foregroundStyle(BillbiColor.textPrimary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(BillbiColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
