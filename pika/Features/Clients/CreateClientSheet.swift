import SwiftUI

struct CreateClientSheet: View {
    let onCancel: () -> Void
    let onSave: (WorkspaceClientDraft) -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var billingAddress = BillingAddressComponents()
    @State private var defaultTermsDaysValue: Int

    init(
        defaultTermsDays: Int,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceClientDraft) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        _defaultTermsDaysValue = State(initialValue: defaultTermsDays)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Client") {
                    TextField("Name", text: $name)
                    TextField("Billing email", text: $email)
                    VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                        TextField("Street and number", text: $billingAddress.street)
                        HStack(spacing: PikaSpacing.sm) {
                            TextField("Postal code", text: $billingAddress.postalCode)
                                .frame(maxWidth: 120)
                            TextField("City", text: $billingAddress.city)
                            TextField("Country", text: $billingAddress.country)
                                .frame(maxWidth: 180)
                        }
                    }
                }

                Section("Invoice defaults") {
                    Stepper(
                        value: $defaultTermsDaysValue,
                        in: 1...120
                    ) {
                        LabeledContent("Payment terms", value: "\(defaultTermsDaysValue) days")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.pikaAction(.destructive))

                Spacer()

                Button {
                    onSave(WorkspaceClientDraft(
                        name: name,
                        email: email,
                        billingAddress: billingAddress.singleString,
                        defaultTermsDays: defaultTermsDaysValue
                    ))
                } label: {
                    Label("Create Client", systemImage: "person.crop.circle.badge.plus")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 360)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !billingAddress.singleString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && defaultTermsDaysValue > 0
    }
}
