import SwiftUI

struct SettingsPaymentDetailsSection: View {
    @Binding var draft: WorkspaceBusinessProfileDraft

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: "Payment methods")

                Spacer()

                Menu {
                    ForEach(WorkspacePaymentMethodType.allCases, id: \.self) { type in
                        Button(type.displayName) {
                            addMethod(type)
                        }
                    }
                } label: {
                    Label("Add provider", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .font(BillbiTypography.entryHelper)
                .tint(BillbiColor.brand)
            }

            VStack(spacing: 0) {
                if draft.paymentMethods.isEmpty {
                    SettingsPaymentEmptyRow {
                        addMethod(.sepaBankTransfer)
                    }
                } else {
                    ForEach($draft.paymentMethods) { $method in
                        SettingsPaymentMethodRow(
                            method: $method,
                            isDefault: draft.defaultPaymentMethodID == method.id,
                            canMoveUp: method.sortOrder > 0,
                            canMoveDown: method.sortOrder < draft.paymentMethods.count - 1,
                            onMakeDefault: {
                                draft.defaultPaymentMethodID = method.id
                            },
                            onMoveUp: {
                                move(method.id, offset: -1)
                            },
                            onMoveDown: {
                                move(method.id, offset: 1)
                            },
                            onDelete: {
                                delete(method.id)
                            }
                        )

                        if method.id != draft.paymentMethods.last?.id {
                            Divider()
                                .overlay(BillbiColor.border)
                        }
                    }
                }
            }
            .billbiSurface()
        }
    }

    private func addMethod(_ type: WorkspacePaymentMethodType) {
        let method = WorkspacePaymentMethod(
            title: type.displayName,
            type: type,
            sortOrder: draft.paymentMethods.count
        )
        draft.paymentMethods.append(method)
        if draft.defaultPaymentMethodID == nil {
            draft.defaultPaymentMethodID = method.id
        }
    }

    private func move(_ id: WorkspacePaymentMethod.ID, offset: Int) {
        guard let currentIndex = draft.paymentMethods.firstIndex(where: { $0.id == id }) else {
            return
        }
        let targetIndex = currentIndex + offset
        guard targetIndex >= 0, targetIndex < draft.paymentMethods.count else {
            return
        }
        draft.paymentMethods.swapAt(currentIndex, targetIndex)
        normalizeSortOrder()
    }

    private func delete(_ id: WorkspacePaymentMethod.ID) {
        draft.paymentMethods.removeAll { $0.id == id }
        normalizeSortOrder()
        if draft.defaultPaymentMethodID == id {
            draft.defaultPaymentMethodID = draft.paymentMethods.first?.id
        }
    }

    private func normalizeSortOrder() {
        for index in draft.paymentMethods.indices {
            draft.paymentMethods[index].sortOrder = index
        }
    }
}

private struct SettingsPaymentMethodRow: View {
    @Binding var method: WorkspacePaymentMethod
    let isDefault: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMakeDefault: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    private var validation: WorkspacePaymentMethodValidation {
        method.validation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            HStack(spacing: BillbiSpacing.md) {
                TextField("Provider name", text: $method.title)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)

                Picker("Provider type", selection: $method.type) {
                    ForEach(WorkspacePaymentMethodType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(width: 210, alignment: .leading)

                Toggle("Print", isOn: $method.isVisible)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                Button {
                    onMakeDefault()
                } label: {
                    Label(isDefault ? "Default" : "Make default", systemImage: isDefault ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isDefault ? BillbiColor.brand : BillbiColor.textSecondary)

                Spacer()

                SettingsPaymentMethodActions(
                    canMoveUp: canMoveUp,
                    canMoveDown: canMoveDown,
                    onMoveUp: onMoveUp,
                    onMoveDown: onMoveDown,
                    onDelete: onDelete
                )
            }

            methodFields

            if !validation.blockingMessages.isEmpty {
                SettingsPaymentValidationMessages(messages: validation.blockingMessages, tone: .error)
            }
            if !validation.warningMessages.isEmpty {
                SettingsPaymentValidationMessages(messages: validation.warningMessages, tone: .warning)
            }
        }
        .font(BillbiTypography.entryHelper)
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, BillbiSpacing.sm)
        .background(BillbiColor.surface)
    }

    @ViewBuilder
    private var methodFields: some View {
        switch method.type {
        case .sepaBankTransfer:
            SettingsPaymentBankFields(method: $method, includesInstructions: false)
        case .internationalBankTransfer:
            SettingsPaymentBankFields(method: $method, includesInstructions: true)
        case .paypal:
            SettingsPaymentContactFields(method: $method, providerLabel: "PayPal", includesInstructions: false)
        case .wise:
            SettingsPaymentContactFields(method: $method, providerLabel: "Wise", includesInstructions: true)
        case .paymentLink:
            SettingsPaymentURLField(method: $method, placeholder: "https://pay.example.com/invoice")
        case .other:
            SettingsPaymentInstructionsField(method: $method, placeholder: "Payment instructions")
        }
    }
}

private struct SettingsPaymentBankFields: View {
    @Binding var method: WorkspacePaymentMethod
    let includesInstructions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            HStack(spacing: BillbiSpacing.sm) {
                TextField("Account holder", text: $method.accountHolder)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
                TextField("IBAN / account number", text: $method.iban)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
                TextField("BIC / SWIFT", text: $method.bic)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
                    .frame(maxWidth: 180)
            }
            if includesInstructions {
                SettingsPaymentInstructionsField(method: $method, placeholder: "International transfer instructions")
            }
        }
    }
}

private struct SettingsPaymentContactFields: View {
    @Binding var method: WorkspacePaymentMethod
    let providerLabel: String
    let includesInstructions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            HStack(spacing: BillbiSpacing.sm) {
                TextField("\(providerLabel) email", text: $method.email)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
                TextField("\(providerLabel) link", text: $method.url)
                    .textFieldStyle(.billbiInput)
                    .controlSize(.small)
            }
            if includesInstructions {
                SettingsPaymentInstructionsField(method: $method, placeholder: "\(providerLabel) instructions")
            }
        }
    }
}

private struct SettingsPaymentURLField: View {
    @Binding var method: WorkspacePaymentMethod
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $method.url)
            .textFieldStyle(.billbiInput)
            .controlSize(.small)
    }
}

private struct SettingsPaymentInstructionsField: View {
    @Binding var method: WorkspacePaymentMethod
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $method.instructions)
            .textFieldStyle(.billbiInput)
            .controlSize(.small)
    }
}

private struct SettingsPaymentMethodActions: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Button(action: onMoveUp) {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveUp ? BillbiColor.textSecondary : BillbiColor.textMuted)
            .disabled(!canMoveUp)

            Button(action: onMoveDown) {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.plain)
            .foregroundStyle(canMoveDown ? BillbiColor.textSecondary : BillbiColor.textMuted)
            .disabled(!canMoveDown)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(BillbiColor.danger)
        }
    }
}

private struct SettingsPaymentValidationMessages: View {
    enum Tone {
        case error
        case warning
    }

    let messages: [String]
    let tone: Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(messages, id: \.self) { message in
                Label(message, systemImage: tone == .error ? "exclamationmark.triangle.fill" : "info.circle")
                    .font(BillbiTypography.small)
                    .foregroundStyle(tone == .error ? BillbiColor.danger : BillbiColor.textSecondary)
            }
        }
    }
}

private struct SettingsPaymentEmptyRow: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            Text("Add a payment provider so invoices can print valid payment instructions.")
                .font(BillbiTypography.body)
                .foregroundStyle(BillbiColor.textSecondary)

            Button(action: onAdd) {
                Label("Add SEPA bank transfer", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .tint(BillbiColor.brand)
        }
        .padding(BillbiSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
