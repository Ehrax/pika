import SwiftUI

struct SettingsView: View {
    let profile: BusinessProfileProjection

    init(profile: BusinessProfileProjection) {
        self.profile = profile
    }

    var body: some View {
        Form {
            Section("Business Profile") {
                LabeledContent("Business name", value: profile.businessName)
                LabeledContent("Email", value: profile.email)
                LabeledContent("Address", value: profile.address)
            }

            Section("Invoice Numbering") {
                LabeledContent("Prefix", value: profile.invoicePrefix)
                LabeledContent("Next number", value: "\(profile.nextInvoiceNumber)")
            }

            Section("Defaults") {
                LabeledContent("Currency", value: profile.currencyCode)
                LabeledContent("Payment terms", value: "\(profile.defaultTermsDays) days")
            }

            Section("Payment Details") {
                Text(profile.paymentDetails)
            }

            Section("Tax / VAT Note") {
                Text(profile.taxNote)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(PikaColor.background)
        .navigationTitle("Settings")
        .toolbar {
            Button {
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .disabled(true)
            .help("Settings persistence lands in a later task")
        }
        .accessibilityIdentifier("SettingsView")
    }
}
