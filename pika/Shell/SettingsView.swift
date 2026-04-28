import SwiftUI

struct SettingsView: View {
    let profile: BusinessProfileProjection
    private let injectedWorkspaceStore: WorkspaceStore?
    @Environment(\.workspaceStore) private var environmentWorkspaceStore
    @State private var draft: WorkspaceBusinessProfileDraft
    @State private var savedDraft: WorkspaceBusinessProfileDraft
    @State private var saveFailure: SettingsSaveFailure?

    init(profile: BusinessProfileProjection, workspaceStore: WorkspaceStore? = nil) {
        self.profile = profile
        injectedWorkspaceStore = workspaceStore
        let draft = WorkspaceBusinessProfileDraft(profile: profile)
        _draft = State(initialValue: draft)
        _savedDraft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section("Business Profile") {
                TextField("Business name", text: $draft.businessName)
                TextField("Email", text: $draft.email)
                TextField("Address", text: $draft.address, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Invoice Numbering") {
                TextField("Prefix", text: $draft.invoicePrefix)
                TextField("Next number", value: $draft.nextInvoiceNumber, format: .number)
            }

            Section("Defaults") {
                CurrencyCodeField("Currency", text: $draft.currencyCode)
                TextField("Payment terms", value: $draft.defaultTermsDays, format: .number)
            }

            Section("Payment Details") {
                TextField("Payment details", text: $draft.paymentDetails, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Tax / VAT Note") {
                TextField("Tax / VAT note", text: $draft.taxNote, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let saveFailure {
                Text(saveFailure.message)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.danger)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(PikaColor.background)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    revertChanges()
                } label: {
                    Label("Revert", systemImage: "arrow.uturn.backward")
                }
                .disabled(!hasChanges)
                .help("Revert settings changes")

                Button {
                    saveChanges()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .disabled(!hasChanges)
                .help("Save settings")
            }
        }
        .onChange(of: profile) { _, newProfile in
            let wasDirty = hasChanges
            let updatedDraft = WorkspaceBusinessProfileDraft(profile: newProfile)
            savedDraft = updatedDraft
            if !wasDirty {
                draft = updatedDraft
            }
        }
        .accessibilityIdentifier("SettingsView")
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
            saveFailure = nil
        } catch WorkspaceStoreError.invalidBusinessProfile {
            saveFailure = SettingsSaveFailure(
                message: "Business name, email, address, invoice prefix, currency, payment details, tax note, payment terms, and next number are required."
            )
        } catch {
            saveFailure = SettingsSaveFailure(message: "Settings could not be saved.")
        }
    }

    private func revertChanges() {
        draft = savedDraft
        saveFailure = nil
    }
}

private struct SettingsSaveFailure: Identifiable {
    let id = UUID()
    let message: String
}
