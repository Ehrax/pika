import SwiftUI

struct InlineEntryEditor: View {
    let date: Date
    let hourlyRateMinorUnits: Int
    let onSave: (WorkspaceTimeEntryDraft) -> Void

    @State private var timeInput = "10:00-12:00"
    @State private var description = ""
    @State private var isBillable = true
    @FocusState private var focusedField: Field?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: PikaSpacing.md) {
                Text(dateLabel)
                    .font(.caption.monospacedDigit())
                    .frame(width: 64, alignment: .leading)

                TextField("10:00-12:00", text: $timeInput)
                    .textFieldStyle(.plain)
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, PikaSpacing.sm)
                    .frame(width: 110, height: 28, alignment: .leading)
                    .background(PikaColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: PikaRadius.sm)
                            .stroke(focusedField == .time ? PikaColor.accent : PikaColor.borderStrong, lineWidth: 1)
                    }
                    .focused($focusedField, equals: .time)
                    .onSubmit {
                        focusedField = .description
                    }

                TextField("what did you work on?", text: $description)
                    .textFieldStyle(.plain)
                    .font(PikaTypography.body)
                    .padding(.horizontal, PikaSpacing.sm)
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .background(PikaColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: PikaRadius.sm)
                            .stroke(focusedField == .description ? PikaColor.accent : PikaColor.borderStrong, lineWidth: 1)
                    }
                    .focused($focusedField, equals: .description)
                    .onSubmit {
                        saveDraft()
                    }

                Text(draft.hoursLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PikaColor.textMuted)
                    .frame(width: 60, alignment: .trailing)

                Text(draft.amountLabel)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(PikaColor.textMuted)
                    .frame(width: 92, alignment: .trailing)
            }
            .padding(.horizontal, PikaSpacing.md)
            .padding(.vertical, 10)
            .background(PikaColor.accentMuted)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PikaColor.accent)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PikaColor.accent)
                    .frame(height: 1)
            }

            helperLine
        }
        .onAppear {
            focusedField = .time
        }
        .onExitCommand {
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
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var helperLine: some View {
        HStack(spacing: PikaSpacing.sm) {
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
            Toggle("Billable", isOn: $isBillable)
                .toggleStyle(.checkbox)
                .font(PikaTypography.small)
            Text("type ranges like 10-12 or 2h")
                .foregroundStyle(PikaColor.textSecondary)
        }
        .font(PikaTypography.small)
        .foregroundStyle(PikaColor.textMuted)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, PikaSpacing.sm)
        .background(PikaColor.surfaceAlt)
    }

    private func resetDraft() {
        timeInput = "10:00-12:00"
        description = ""
        isBillable = true
        focusedField = .time
    }

    private func saveDraft() {
        guard draft.durationMinutes != nil,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            focusedField = description.isEmpty ? .description : .time
            return
        }

        onSave(WorkspaceTimeEntryDraft(
            date: date,
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

private struct HelperKey: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.monospacedDigit())
            .foregroundStyle(PikaColor.textPrimary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(PikaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
