import SwiftUI

struct SettingsInvoiceNumberingSection: View {
    @Binding var draft: WorkspaceBusinessProfileDraft

    var body: some View {
        SettingsSection(title: "Invoice numbering") {
            SettingsEditableFieldRow(label: "Prefix") {
                TextField("Prefix", text: $draft.invoicePrefix)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "Next number") {
                Stepper(value: $draft.nextInvoiceNumber, in: 1...999_999) {
                    Text("\(draft.nextInvoiceNumber)")
                        .font(BillbiTypography.body.monospacedDigit())
                }
            }
        }
    }
}

struct SettingsInvoiceDefaultsSection: View {
    @Binding var draft: WorkspaceBusinessProfileDraft

    var body: some View {
        SettingsSection(title: "Payment terms") {
            SettingsEditableFieldRow(label: "Payment terms") {
                Stepper(value: $draft.defaultTermsDays, in: 1...120) {
                    Text("\(draft.defaultTermsDays) days")
                        .font(BillbiTypography.body.monospacedDigit())
                }
            }
        }
    }
}
