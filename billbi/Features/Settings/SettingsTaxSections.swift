import SwiftUI

struct SettingsTaxIdentitySection: View {
    @Binding var draft: WorkspaceBusinessProfileDraft

    var body: some View {
        SettingsSection(title: "Tax & Legal") {
            ForEach($draft.senderTaxLegalFields) { $field in
                VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                    HStack(spacing: BillbiSpacing.sm) {
                        TextField("Label", text: $field.label)
                            .textFieldStyle(.billbiInput)
                            .controlSize(.small)

                        TextField("Value", text: $field.value)
                            .textFieldStyle(.billbiInput)
                            .controlSize(.small)
                    }

                    HStack(spacing: BillbiSpacing.sm) {
                        Picker("Placement", selection: $field.placement) {
                            Text("Sender details").tag(TaxLegalFieldPlacement.senderDetails)
                            Text("Recipient details").tag(TaxLegalFieldPlacement.recipientDetails)
                            Text("Footer").tag(TaxLegalFieldPlacement.footer)
                            Text("Hidden").tag(TaxLegalFieldPlacement.hidden)
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)

                        Toggle("Visible", isOn: $field.isVisible)
                            .toggleStyle(.switch)
                            .controlSize(.small)

                        Spacer()

                        Button {
                            move(field.id, offset: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.plain)
                        .disabled(field.sortOrder == 0)

                        Button {
                            move(field.id, offset: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.plain)
                        .disabled(field.sortOrder >= draft.senderTaxLegalFields.count - 1)

                        Button(role: .destructive) {
                            draft.senderTaxLegalFields.removeAll { $0.id == field.id }
                            normalizeSortOrder()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
                SettingsDivider()
            }

            Button {
                draft.senderTaxLegalFields.append(WorkspaceTaxLegalField(
                    label: "",
                    value: "",
                    placement: .senderDetails,
                    isVisible: true,
                    sortOrder: draft.senderTaxLegalFields.count
                ))
            } label: {
                Label("Add field", systemImage: "plus")
            }
            .buttonStyle(.plain)
        }
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
