import SwiftUI

struct SettingsProfileSection: View {
    @Binding var draft: WorkspaceBusinessProfileDraft
    @Binding var address: BillingAddressComponents
    private let countryOptions = ISOCountryCatalog.options()

    var body: some View {
        SettingsSection(title: "Business profile") {
            SettingsEditableFieldRow(label: "Business name") {
                TextField("Business name", text: $draft.businessName)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "Person name") {
                TextField("Person name", text: $draft.personName)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "Email") {
                TextField("Email", text: $draft.email)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "Phone") {
                TextField("Phone", text: $draft.phone)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "Address", alignment: .top) {
                VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                    TextField("Street and number", text: $address.street)
                        .textFieldStyle(.billbiInput)
                        .controlSize(.small)

                    HStack(spacing: BillbiSpacing.sm) {
                        TextField("Postal code", text: $address.postalCode)
                            .textFieldStyle(.billbiInput)
                            .controlSize(.small)
                            .frame(maxWidth: 120)

                        TextField("City", text: $address.city)
                            .textFieldStyle(.billbiInput)
                            .controlSize(.small)

                        TextField("Country", text: $address.country)
                            .textFieldStyle(.billbiInput)
                            .controlSize(.small)
                            .frame(maxWidth: 180)
                    }
                }
            }
            SettingsDivider()
            SettingsEditableFieldRow(label: "Business country/region") {
                Picker(
                    "Business country/region",
                    selection: $draft.countryCode
                ) {
                    Text("None").tag("")
                    ForEach(countryOptions) { option in
                        Text("\(option.localizedName) (\(option.code))")
                            .tag(option.code)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
            }
        }
    }
}
