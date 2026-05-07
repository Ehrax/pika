import SwiftUI

struct SettingsFeatureView: View {
    let profile: BusinessProfileProjection
    private let injectedWorkspaceStore: WorkspaceStore?
    @Environment(\.workspaceStore) private var environmentWorkspaceStore
    @SceneStorage("billbi.settings.selectedCategory") private var selectedCategoryRawValue = SettingsCategory.profile.rawValue
    @State private var draft: WorkspaceBusinessProfileDraft
    @State private var savedDraft: WorkspaceBusinessProfileDraft
    @State private var address = BillingAddressComponents()
    @State private var paymentDetails = PaymentDetailsComponents()
    @State private var saveFailure: SettingsSaveFailure?
    @FocusState private var focusedField: SettingsField?

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
        ResizableDetailSplitView {
            SettingsCategoryColumn(
                selectedCategory: selectedCategory,
                hasChanges: hasChanges,
                onSelect: { selectedCategory = $0 }
            )
        } detail: {
            selectedSettingsDetail
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

    private var selectedCategory: SettingsCategory {
        get {
            SettingsCategory(rawValue: selectedCategoryRawValue) ?? .profile
        }
        nonmutating set {
            selectedCategoryRawValue = newValue.rawValue
        }
    }

    private var selectedSettingsDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BillbiSpacing.md) {
                settingsDetailHeader

                switch selectedCategory {
                case .profile:
                    SettingsProfileSection(draft: $draft, address: $address)
                case .invoicing:
                    SettingsInvoiceNumberingSection(draft: $draft)
                    SettingsInvoiceDefaultsSection(draft: $draft)
                case .tax:
                    SettingsTaxIdentitySection(draft: $draft)
                    SettingsTaxNoteSection(taxNote: $draft.taxNote, focusedField: $focusedField)
                case .payment:
                    SettingsPaymentDetailsSection(paymentDetails: $paymentDetails)
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
    }

    private var settingsDetailHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: BillbiSpacing.sm) {
                Image(systemName: selectedCategory.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BillbiColor.brand)
                    .frame(width: 24)

                Text(selectedCategory.title)
                    .font(BillbiTypography.display)
                    .foregroundStyle(BillbiColor.textPrimary)
            }

            Text(selectedCategory.detail)
                .font(BillbiTypography.body)
                .foregroundStyle(BillbiColor.textSecondary)
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
                message: String(localized: "Business name, email, address, invoice prefix, currency, payment details, payment terms, and next number are required.")
            )
        } catch {
            saveFailure = SettingsSaveFailure(message: String(localized: "Settings could not be saved."))
        }
    }

    private func revertChanges() {
        draft = savedDraft
        address = BillingAddressComponents(rawAddress: savedDraft.address)
        paymentDetails = PaymentDetailsComponents(rawValue: savedDraft.paymentDetails)
        saveFailure = nil
    }
}
