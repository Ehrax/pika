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
                    businessProfileSection
                case .invoicing:
                    invoiceNumberingSection
                    invoiceDefaultsSection
                case .tax:
                    taxIdentitySection
                    taxNoteSection
                case .payment:
                    paymentDetailsSection
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
                    .foregroundStyle(BillbiColor.accent)
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

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            SectionHeader(title: title)

            VStack(spacing: 0) {
                content()
            }
            .billbiSurface()
        }
    }

    private var businessProfileSection: some View {
        settingsSection(title: "Business profile") {
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
        }
    }

    private var invoiceNumberingSection: some View {
        settingsSection(title: "Invoice numbering") {
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
    }

    private var invoiceDefaultsSection: some View {
        settingsSection(title: "Defaults") {
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
    }

    private var taxIdentitySection: some View {
        settingsSection(title: "Tax identity") {
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
    }

    private var taxNoteSection: some View {
        settingsSection(title: "Tax / VAT note") {
            SettingsEditableFieldRow(label: "Default note", alignment: .top) {
                TextEditor(text: $draft.taxNote)
                    .font(BillbiTypography.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 84)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(BillbiColor.inputSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous)
                            .stroke(BillbiColor.border, lineWidth: 1)
                    }
                    .accessibilityLabel("Tax / VAT note")
            }
        }
    }

    private var paymentDetailsSection: some View {
        settingsSection(title: "Payment details") {
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

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case profile
    case invoicing
    case tax
    case payment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile:
            String(localized: "Profile")
        case .invoicing:
            String(localized: "Invoicing")
        case .tax:
            String(localized: "Tax")
        case .payment:
            String(localized: "Payment")
        }
    }

    var detail: String {
        switch self {
        case .profile:
            String(localized: "Used on every invoice header and PDF.")
        case .invoicing:
            String(localized: "Numbering, currency, and payment terms.")
        case .tax:
            String(localized: "Identifiers and VAT notes for invoice compliance.")
        case .payment:
            String(localized: "Bank details printed in invoice footers.")
        }
    }

    var systemImage: String {
        switch self {
        case .profile:
            "person.crop.square"
        case .invoicing:
            "doc.text"
        case .tax:
            "percent"
        case .payment:
            "creditcard"
        }
    }
}

private struct SettingsCategoryColumn: View {
    let selectedCategory: SettingsCategory
    let hasChanges: Bool
    let onSelect: (SettingsCategory) -> Void

    var body: some View {
        BillbiSecondarySidebarColumn(
            title: "Settings",
            subtitle: hasChanges ? "Unsaved changes" : "Workspace preferences",
            sectionTitle: "Categories",
            wrapsContentInScrollView: false
        ) {
            EmptyView()
        } controls: {
            EmptyView()
        } content: {
            VStack(spacing: 0) {
                Divider()
                categoryList
                    .padding(.top, BillbiSpacing.md)
            }
        }
    }

    private var categoryList: some View {
        List {
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    onSelect(category)
                } label: {
                    SettingsCategoryRow(category: category, isSelected: selectedCategory == category)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: BillbiSpacing.sm, bottom: 1, trailing: BillbiSpacing.sm))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BillbiColor.surface)
    }
}

private struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: category.systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(BillbiTypography.body.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)

                Text(category.detail)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)
        }
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: isSelected)
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
