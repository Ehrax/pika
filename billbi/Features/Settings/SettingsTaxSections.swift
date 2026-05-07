import SwiftUI

struct SettingsTaxIdentitySection: View {
    @Binding var draft: WorkspaceBusinessProfileDraft

    var body: some View {
        SettingsSection(title: "Tax identity") {
            SettingsEditableFieldRow(label: "Tax identifier") {
                TextField("Tax identifier", text: $draft.taxIdentifier)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "Wirtschafts-IdNr") {
                TextField("Wirtschafts-IdNr", text: $draft.economicIdentifier)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
        }
    }
}

struct SettingsTaxNoteSection: View {
    @Binding var taxNote: String
    var focusedField: FocusState<SettingsField?>.Binding

    var body: some View {
        SettingsSection(title: "Tax / VAT note") {
            SettingsEditableFieldRow(label: "Default note", alignment: .top) {
                TextEditor(text: $taxNote)
                    .font(BillbiTypography.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 84)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(BillbiColor.inputSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous)
                            .stroke(
                                focusedField.wrappedValue == .taxNote ? BillbiColor.brandBorder : BillbiColor.border,
                                lineWidth: focusedField.wrappedValue == .taxNote ? BillbiColor.inputFocusBorderWidth : 1
                            )
                    }
                    .focused(focusedField, equals: .taxNote)
                    .accessibilityLabel("Tax / VAT note")
            }
        }
    }
}
