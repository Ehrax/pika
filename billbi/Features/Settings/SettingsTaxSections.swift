import SwiftUI

private enum SettingsTaxFieldTableLayout {
    static let labelWidth: CGFloat = 220
    static let placementWidth: CGFloat = 150
    static let visibleWidth: CGFloat = 72
    static let actionsWidth: CGFloat = 88
    static let inputHeight: CGFloat = 26
}

struct SettingsTaxIdentitySection: View {
    @Binding var draft: WorkspaceBusinessProfileDraft

    var body: some View {
        SettingsSection(title: "Tax & Legal") {
            SettingsTaxFieldHeaderRow()

            ForEach($draft.senderTaxLegalFields) { $field in
                SettingsTaxFieldRow(
                    field: $field,
                    canMoveUp: field.sortOrder > 0,
                    canMoveDown: field.sortOrder < draft.senderTaxLegalFields.count - 1,
                    onMoveUp: {
                        move(field.id, offset: -1)
                    },
                    onMoveDown: {
                        move(field.id, offset: 1)
                    },
                    onDelete: {
                        draft.senderTaxLegalFields.removeAll { $0.id == field.id }
                        normalizeSortOrder()
                    }
                )

                Divider()
                    .overlay(BillbiColor.border)
            }

            SettingsTaxFieldAddRow {
                addField()
            }
        }
    }

    private func addField() {
        draft.senderTaxLegalFields.append(WorkspaceTaxLegalField(
            label: "",
            value: "",
            placement: .senderDetails,
            isVisible: true,
            sortOrder: draft.senderTaxLegalFields.count
        ))
    }

    private func move(_ id: WorkspaceTaxLegalField.ID, offset: Int) {
        guard let currentIndex = draft.senderTaxLegalFields.firstIndex(where: { $0.id == id }) else {
            return
        }
        let targetIndex = currentIndex + offset
        guard targetIndex >= 0, targetIndex < draft.senderTaxLegalFields.count else {
            return
        }
        draft.senderTaxLegalFields.swapAt(currentIndex, targetIndex)
        normalizeSortOrder()
    }

    private func normalizeSortOrder() {
        for index in draft.senderTaxLegalFields.indices {
            draft.senderTaxLegalFields[index].sortOrder = index
        }
    }
}

private struct SettingsTaxFieldHeaderRow: View {
    var body: some View {
        HStack(spacing: BillbiSpacing.md) {
            Text("Label")
                .frame(width: SettingsTaxFieldTableLayout.labelWidth, alignment: .leading)
            Text("Value")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Placement")
                .frame(width: SettingsTaxFieldTableLayout.placementWidth, alignment: .leading)
            Text("Visible")
                .frame(width: SettingsTaxFieldTableLayout.visibleWidth, alignment: .center)
            Spacer()
                .frame(width: SettingsTaxFieldTableLayout.actionsWidth)
        }
        .font(BillbiTypography.entry.weight(.medium))
        .foregroundStyle(BillbiColor.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, 8)
        .background(BillbiColor.surfaceAlt)
    }
}

private struct SettingsTaxFieldRow: View {
    @Binding var field: WorkspaceTaxLegalField
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: BillbiSpacing.md) {
            TextField("Label", text: $field.label)
                .settingsTaxTableInput(width: SettingsTaxFieldTableLayout.labelWidth)

            TextField("Value", text: $field.value)
                .settingsTaxTableInput()

            Picker("Placement", selection: $field.placement) {
                Text("Sender details").tag(TaxLegalFieldPlacement.senderDetails)
                Text("Recipient details").tag(TaxLegalFieldPlacement.recipientDetails)
                Text("Footer").tag(TaxLegalFieldPlacement.footer)
                Text("Hidden").tag(TaxLegalFieldPlacement.hidden)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: SettingsTaxFieldTableLayout.placementWidth, alignment: .leading)

            Toggle("Visible", isOn: $field.isVisible)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .frame(width: SettingsTaxFieldTableLayout.visibleWidth, alignment: .center)

            HStack(spacing: BillbiSpacing.sm) {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveUp ? BillbiColor.textSecondary : BillbiColor.textMuted)
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveDown ? BillbiColor.textSecondary : BillbiColor.textMuted)
                .disabled(!canMoveDown)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(BillbiColor.danger)
            }
            .font(BillbiTypography.entryHelper)
            .frame(width: SettingsTaxFieldTableLayout.actionsWidth, alignment: .trailing)
        }
        .font(BillbiTypography.entry)
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, 10)
        .background(BillbiColor.surface)
    }
}

private struct SettingsTaxFieldAddRow: View {
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            Label("Add field", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .font(BillbiTypography.entryHelper)
        .foregroundStyle(BillbiColor.brand)
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, BillbiSpacing.sm)
        .background(BillbiColor.surfaceAlt)
    }
}

private extension View {
    @ViewBuilder
    func settingsTaxTableInput(width: CGFloat? = nil) -> some View {
        let input = textFieldStyle(.plain)
            .font(BillbiTypography.input)
            .padding(.horizontal, BillbiSpacing.sm)
            .background(BillbiColor.inputSurface)
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous)
                    .stroke(BillbiColor.borderStrong, lineWidth: 1)
            }

        if let width {
            input.frame(width: width, height: SettingsTaxFieldTableLayout.inputHeight, alignment: .leading)
        } else {
            input.frame(maxWidth: .infinity, minHeight: SettingsTaxFieldTableLayout.inputHeight, alignment: .leading)
        }
    }
}
