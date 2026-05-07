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
            ScrollView {
                VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                    BillbiInputSheetSection(title: "Client") {
                        BillbiInputSheetFieldRow(label: "Name") {
                            TextField("Name", text: $name)
                                .textFieldStyle(.billbiInput)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Billing email") {
                            TextField("Billing email", text: $email)
                                .textFieldStyle(.billbiInput)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Street and number") {
                            TextField("Street and number", text: $billingAddress.street)
                                .textFieldStyle(.billbiInput)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Postal code") {
                            TextField("Postal code", text: $billingAddress.postalCode)
                                .textFieldStyle(.billbiInput)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "City") {
                            TextField("City", text: $billingAddress.city)
                                .textFieldStyle(.billbiInput)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Country") {
                            TextField("Country", text: $billingAddress.country)
                                .textFieldStyle(.billbiInput)
                        }
                    }

                    BillbiInputSheetSection(title: "Invoice defaults") {
                        BillbiInputSheetFieldRow(label: "Payment terms") {
                            HStack(spacing: BillbiSpacing.sm) {
                                Text("\(defaultTermsDaysValue) days")
                                    .font(BillbiTypography.body.monospacedDigit())
                                Stepper("", value: $defaultTermsDaysValue, in: 1...120)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(BillbiSpacing.md)
            }

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.billbiAction(.destructive))

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
                .buttonStyle(.billbiAction(.primary))
                .disabled(!canSave)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 360)
        .background(BillbiColor.background)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !billingAddress.singleString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && defaultTermsDaysValue > 0
    }
}
