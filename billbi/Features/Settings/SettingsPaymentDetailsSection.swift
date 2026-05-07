import SwiftUI

struct SettingsPaymentDetailsSection: View {
    @Binding var paymentDetails: PaymentDetailsComponents

    var body: some View {
        SettingsSection(title: "Payment details") {
            SettingsEditableFieldRow(label: "Account name") {
                TextField("Account name", text: $paymentDetails.accountName)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "IBAN") {
                TextField("IBAN", text: $paymentDetails.iban)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "BIC") {
                TextField("BIC", text: $paymentDetails.bic)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
        }
    }
}
