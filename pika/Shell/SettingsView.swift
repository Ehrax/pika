import SwiftUI

struct SettingsView: View {
    let profile: BusinessProfileProjection
    private let injectedWorkspaceStore: WorkspaceStore?
    @Environment(\.workspaceStore) private var environmentWorkspaceStore
    @State private var draft: WorkspaceBusinessProfileDraft
    @State private var savedDraft: WorkspaceBusinessProfileDraft
    @State private var address = BusinessAddressComponents()
    @State private var paymentDetails = PaymentDetailsComponents()
    @State private var saveFailure: SettingsSaveFailure?

    init(profile: BusinessProfileProjection, workspaceStore: WorkspaceStore? = nil) {
        self.profile = profile
        injectedWorkspaceStore = workspaceStore
        let draft = WorkspaceBusinessProfileDraft(profile: profile)
        _draft = State(initialValue: draft)
        _savedDraft = State(initialValue: draft)
        _address = State(initialValue: BusinessAddressComponents(rawAddress: draft.address))
        _paymentDetails = State(initialValue: PaymentDetailsComponents(rawValue: draft.paymentDetails))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                settingsSection(title: "Business profile", detail: hasChanges ? "Unsaved changes" : "Saved") {
                    SettingsEditableFieldRow(label: "Business name") {
                        TextField("Business name", text: $draft.businessName)
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
                        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                            TextField("Street and number", text: $address.street)
                                .textFieldStyle(.roundedBorder)
                                .controlSize(.small)

                            HStack(spacing: PikaSpacing.sm) {
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
                    SettingsEditableFieldRow(label: "Economic identifier") {
                        TextField("Economic identifier", text: $draft.economicIdentifier)
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
                                .font(PikaTypography.body.monospacedDigit())
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
                                .font(PikaTypography.body.monospacedDigit())
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
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.danger)
                        .padding(.horizontal, PikaSpacing.xl + PikaSpacing.md)
                }
            }
            .padding(.horizontal, PikaSpacing.xl + PikaSpacing.md)
            .padding(.vertical, PikaSpacing.lg)
        }
        .background(PikaColor.background)
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
                    .tint(PikaColor.textPrimary)

                    Button {
                        saveChanges()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .disabled(!hasChanges)
                    .help("Save settings")
                    .tint(PikaColor.textPrimary)
                }
            }
        }
        .onChange(of: profile) { _, newProfile in
            let wasDirty = hasChanges
            let updatedDraft = WorkspaceBusinessProfileDraft(profile: newProfile)
            savedDraft = updatedDraft
            if !wasDirty {
                draft = updatedDraft
                address = BusinessAddressComponents(rawAddress: updatedDraft.address)
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
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            SectionHeader(title: title, detail: detail)

            VStack(spacing: 0) {
                content()
            }
            .pikaSurface()
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
            address = BusinessAddressComponents(rawAddress: updatedDraft.address)
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
        address = BusinessAddressComponents(rawAddress: savedDraft.address)
        paymentDetails = PaymentDetailsComponents(rawValue: savedDraft.paymentDetails)
        saveFailure = nil
    }
}

private struct SettingsEditableFieldRow<Content: View>: View {
    let label: String
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: PikaSpacing.lg) {
            Text(label)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 180, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, PikaSpacing.sm)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, PikaSpacing.md)
    }
}

private struct SettingsSaveFailure: Identifiable {
    let id = UUID()
    let message: String
}

private struct BusinessAddressComponents: Equatable {
    var street: String = ""
    var postalCode: String = ""
    var city: String = ""
    var country: String = ""

    init() {}

    init(rawAddress: String) {
        let normalized = rawAddress
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            return
        }

        let lines = normalized
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count >= 2 {
            street = lines[0]
            splitPostalAndCity(from: lines[1], fallbackStreet: nil)
            if lines.count >= 3 {
                country = lines[2]
            }
            return
        }

        if normalized.contains(",") {
            let parts = normalized
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if let first = parts.first {
                street = first
            }
            if parts.count > 1 {
                splitPostalAndCity(from: parts[1], fallbackStreet: nil)
            }
            if parts.count > 2 {
                country = parts[2]
            }
            return
        }

        splitPostalAndCity(from: normalized, fallbackStreet: normalized)
    }

    var singleString: String {
        let secondLine = [postalCode, city]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let lines = [
            street.trimmingCharacters(in: .whitespacesAndNewlines),
            secondLine,
            country.trimmingCharacters(in: .whitespacesAndNewlines),
        ].filter { !$0.isEmpty }

        return lines.joined(separator: "\n")
    }

    private mutating func splitPostalAndCity(from input: String, fallbackStreet: String?) {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            if let fallbackStreet {
                street = fallbackStreet
            }
            return
        }

        let pattern = #"\b\d{4,5}\b"#
        guard let range = raw.range(of: pattern, options: .regularExpression) else {
            if let fallbackStreet {
                street = fallbackStreet
            } else {
                city = raw
            }
            return
        }

        let prefix = raw[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let code = raw[range].trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = raw[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)

        postalCode = code
        city = suffix

        if let fallbackStreet, street.isEmpty {
            street = prefix.isEmpty ? fallbackStreet : prefix
        } else if street.isEmpty {
            street = prefix
        }
    }
}

private struct PaymentDetailsComponents: Equatable {
    var iban: String = ""
    var bic: String = ""

    init() {}

    init(rawValue: String) {
        let words = rawValue
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .map(String.init)

        iban = Self.value(after: "IBAN", in: words).map(Self.formattedIBAN) ?? ""
        bic = Self.value(after: "BIC", in: words)?.uppercased() ?? ""
    }

    var rawValue: String {
        var lines: [String] = []
        let normalizedIBAN = Self.formattedIBAN(iban)
        if !normalizedIBAN.isEmpty {
            lines.append("IBAN \(normalizedIBAN)")
        }

        let normalizedBIC = bic.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !normalizedBIC.isEmpty {
            lines.append("BIC \(normalizedBIC)")
        }

        return lines.joined(separator: "\n")
    }

    private static func value(after label: String, in words: [String]) -> String? {
        guard let labelIndex = words.firstIndex(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) else {
            return nil
        }

        let valueWords = words[(labelIndex + 1)...]
            .prefix { word in
                word.caseInsensitiveCompare("IBAN") != .orderedSame
                    && word.caseInsensitiveCompare("BIC") != .orderedSame
            }
        let value = valueWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func formattedIBAN(_ value: String) -> String {
        let cleanValue = value.filter { !$0.isWhitespace }.uppercased()
        return cleanValue.enumerated().reduce(into: "") { result, pair in
            if pair.offset > 0, pair.offset.isMultiple(of: 4) {
                result.append(" ")
            }
            result.append(pair.element)
        }
    }
}
