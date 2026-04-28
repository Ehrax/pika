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
                VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                    PikaInputSheetSection(title: "Client") {
                        PikaInputSheetFieldRow(label: "Name") {
                            TextField("Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Billing email") {
                            TextField("Billing email", text: $email)
                                .textFieldStyle(.roundedBorder)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Street and number") {
                            TextField("Street and number", text: $billingAddress.street)
                                .textFieldStyle(.roundedBorder)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Postal code") {
                            TextField("Postal code", text: $billingAddress.postalCode)
                                .textFieldStyle(.roundedBorder)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "City") {
                            TextField("City", text: $billingAddress.city)
                                .textFieldStyle(.roundedBorder)
                        }
                        PikaInputSheetDivider()
                        PikaInputSheetFieldRow(label: "Country") {
                            TextField("Country", text: $billingAddress.country)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    PikaInputSheetSection(title: "Invoice defaults") {
                        PikaInputSheetFieldRow(label: "Payment terms") {
                            HStack(spacing: PikaSpacing.sm) {
                                Text("\(defaultTermsDaysValue) days")
                                    .font(PikaTypography.body.monospacedDigit())
                                Stepper("", value: $defaultTermsDaysValue, in: 1...120)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(PikaSpacing.md)
            }

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
        .background(PikaColor.background)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !billingAddress.singleString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && defaultTermsDaysValue > 0
    }
}
