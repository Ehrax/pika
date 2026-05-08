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
