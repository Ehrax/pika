import SwiftUI

struct SettingsFeatureView: View {
    let profile: BusinessProfileProjection
    private let injectedWorkspaceStore: WorkspaceStore?
    @Environment(\.workspaceStore) private var environmentWorkspaceStore
    @State private var draft: WorkspaceBusinessProfileDraft
    @State private var savedDraft: WorkspaceBusinessProfileDraft
    @State private var address = BillingAddressComponents()
    @State private var paymentDetails = PaymentDetailsComponents()
    @State private var saveFailure: SettingsSaveFailure?

    init(profile: BusinessProfileProjection, workspaceStore: WorkspaceStore? = nil) {
        self.profile = profile
        injectedWorkspaceStore = workspaceStore
        let draft = WorkspaceBusinessProfileDraft(profile: profile)
        _draft = State(initialValue: draft)
        _savedDraft = State(initialValue: draft)
        _address = State(initialValue: BillingAddressComponents(rawAddress: draft.address))
        _paymentDetails = State(initialValue: PaymentDetailsComponents(rawValue: draft.paymentDetails))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                settingsSection(title: "Business profile", detail: hasChanges ? "Unsaved changes" : "Saved") {
                    SettingsEditableFieldRow(label: "Business name") {
                        TextField("Business name", text: $draft.businessName)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "Person name") {
                        TextField("Person name", text: $draft.personName)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "Email") {
                        TextField("Email", text: $draft.email)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "Phone") {
                        TextField("Phone", text: $draft.phone)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "Address", alignment: .top) {
                        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                            TextField("Street and number", text: $address.street)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)

                            HStack(spacing: BillbiSpacing.sm) {
                                TextField("Postal code", text: $address.postalCode)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    .frame(maxWidth: 120)

                                TextField("City", text: $address.city)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)

                                TextField("Country", text: $address.country)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    .frame(maxWidth: 180)
                            }
                        }
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "Tax identifier") {
                        TextField("Tax identifier", text: $draft.taxIdentifier)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "Wirtschafts-IdNr") {
                        TextField("Wirtschafts-IdNr", text: $draft.economicIdentifier)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                }

                settingsSection(title: "Invoice numbering", detail: "Defaults") {
                    SettingsEditableFieldRow(label: "Prefix") {
                        TextField("Prefix", text: $draft.invoicePrefix)
                            .textFieldStyle(.roundedBorder)
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

                settingsSection(title: "Defaults", detail: "Invoice") {
                    SettingsEditableFieldRow(label: "Currency") {
                        CurrencyCodeField("Currency", text: $draft.currencyCode)
                            .frame(maxWidth: 120, alignment: .leading)
                            .controlSize(.small)
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "Payment terms") {
                        Stepper(value: $draft.defaultTermsDays, in: 1...120) {
                            Text("\(draft.defaultTermsDays) days")
                                .font(BillbiTypography.body.monospacedDigit())
                        }
                    }
                }

                settingsSection(title: "Payment details", detail: "Invoice footer") {
                    SettingsEditableFieldRow(label: "IBAN") {
                        TextField("IBAN", text: $paymentDetails.iban)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    SettingsDivider()
                    SettingsEditableFieldRow(label: "BIC") {
                        TextField("BIC", text: $paymentDetails.bic)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                }

                if let saveFailure {
                    Text(saveFailure.message)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.danger)
                        .padding(.horizontal, BillbiSpacing.xl + BillbiSpacing.md)
                }
            }
            .padding(.horizontal, BillbiSpacing.xl + BillbiSpacing.md)
            .padding(.vertical, BillbiSpacing.lg)
        }
        .background(BillbiColor.background)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItemGroup {
                ControlGroup {
                    Button {
                        revertChanges()
                    } label: {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!hasChanges)
                    .help("Revert settings changes")
                    .tint(BillbiColor.textPrimary)

                    Button {
                        saveChanges()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .disabled(!hasChanges)
                    .help("Save settings")
                    .tint(BillbiColor.textPrimary)
                }
            }
        }
        .onChange(of: profile) { _, newProfile in
            let wasDirty = hasChanges
            let updatedDraft = WorkspaceBusinessProfileDraft(profile: newProfile)
            savedDraft = updatedDraft
            if !wasDirty {
                draft = updatedDraft
                address = BillingAddressComponents(rawAddress: updatedDraft.address)
                paymentDetails = PaymentDetailsComponents(rawValue: updatedDraft.paymentDetails)
            }
        }
        .onChange(of: address) { _, newAddress in
            draft.address = newAddress.singleString
        }
        .onChange(of: paymentDetails) { _, newPaymentDetails in
            draft.paymentDetails = newPaymentDetails.rawValue
        }
        .accessibilityIdentifier("SettingsView")
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            SectionHeader(title: title, detail: detail)

            VStack(spacing: 0) {
                content()
            }
            .billbiSurface()
        }
    }

    private var workspaceStore: WorkspaceStore {
        injectedWorkspaceStore ?? environmentWorkspaceStore
    }

    private var hasChanges: Bool {
        draft != savedDraft
    }

    private func saveChanges() {
        do {
            try workspaceStore.updateBusinessProfile(draft)
            let updatedDraft = WorkspaceBusinessProfileDraft(profile: workspaceStore.workspace.businessProfile)
            draft = updatedDraft
            savedDraft = updatedDraft
            address = BillingAddressComponents(rawAddress: updatedDraft.address)
            paymentDetails = PaymentDetailsComponents(rawValue: updatedDraft.paymentDetails)
            saveFailure = nil
        } catch WorkspaceStoreError.invalidBusinessProfile {
            saveFailure = SettingsSaveFailure(
                message: "Business name, email, address, invoice prefix, currency, payment details, payment terms, and next number are required."
            )
        } catch {
            saveFailure = SettingsSaveFailure(message: "Settings could not be saved.")
        }
    }

    private func revertChanges() {
        draft = savedDraft
        address = BillingAddressComponents(rawAddress: savedDraft.address)
        paymentDetails = PaymentDetailsComponents(rawValue: savedDraft.paymentDetails)
        saveFailure = nil
    }
}

private struct SettingsEditableFieldRow<Content: View>: View {
    let label: String
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: BillbiSpacing.lg) {
            Text(label)
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 180, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, BillbiSpacing.sm)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, BillbiSpacing.md)
    }
}

private struct SettingsSaveFailure: Identifiable {
    let id = UUID()
    let message: String
}
