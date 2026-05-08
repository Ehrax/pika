import SwiftUI

struct ClientDetailHeader: View {
    let client: WorkspaceClient

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                Text(client.name)
                    .font(BillbiTypography.display)
                    .foregroundStyle(BillbiColor.textPrimary)
                Text(client.email)
                    .font(BillbiTypography.body)
                    .foregroundStyle(BillbiColor.textSecondary)
            }

            Spacer()

            HStack(spacing: BillbiSpacing.sm) {
                StatusBadge(client.isArchived ? .neutral : .success, title: client.isArchived ? "Archived" : "Active")
            }
        }
    }
}

struct ClientDetailBillingSection: View {
    @Binding var draft: WorkspaceClientDraft
    @Binding var billingAddress: BillingAddressComponents
    let availablePaymentMethods: [WorkspacePaymentMethod]
    let hasChanges: Bool
    let saveFailure: ClientSaveFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            SectionHeader(title: "Billing details", detail: hasChanges ? "Unsaved changes" : "Saved")

            VStack(spacing: 0) {
                ClientEditableFieldRow(label: "Name") {
                    TextField("Name", text: $draft.name)
                        .textFieldStyle(.billbiInput)
                }
                ClientDivider()
                ClientEditableFieldRow(label: "Email") {
                    TextField("Billing email", text: $draft.email)
                        .textFieldStyle(.billbiInput)
                }
                ClientDivider()
                ClientEditableFieldRow(label: "Billing address", alignment: .top) {
                    VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                        TextField("Street and number", text: $billingAddress.street)
                            .textFieldStyle(.billbiInput)
                        HStack(spacing: BillbiSpacing.sm) {
                            TextField("Postal code", text: $billingAddress.postalCode)
                                .textFieldStyle(.billbiInput)
                                .frame(maxWidth: 120)
                            TextField("City", text: $billingAddress.city)
                                .textFieldStyle(.billbiInput)
                            TextField("Country", text: $billingAddress.country)
                                .textFieldStyle(.billbiInput)
                                .frame(maxWidth: 180)
                        }
                    }
                }
                ClientDivider()
                ClientEditableFieldRow(label: "Payment terms") {
                    Stepper(
                        value: $draft.defaultTermsDays,
                        in: 1...120
                    ) {
                        Text("\(draft.defaultTermsDays) days")
                            .font(BillbiTypography.body.monospacedDigit())
                    }
                }
                if !availablePaymentMethods.isEmpty {
                    ClientDivider()
                    ClientEditableFieldRow(label: "Preferred payment") {
                        Picker("Preferred payment", selection: $draft.preferredPaymentMethodID) {
                            Text("Workspace default").tag(Optional<UUID>.none)
                            ForEach(availablePaymentMethods) { method in
                                Text(method.title).tag(Optional(method.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let saveFailure {
                    ClientDivider()
                    Text(saveFailure.message)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.danger)
                        .padding(BillbiSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .billbiSurface()
        }
    }
}

struct ClientDetailInvoiceDefaultsSection: View {
    let client: WorkspaceClient
    let resolvedPaymentMethodTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            SectionHeader(title: "Invoice defaults", detail: "Client")

            VStack(spacing: 0) {
                ClientFieldRow(label: "Recipient", value: client.name)
                ClientDivider()
                ClientFieldRow(label: "Billing email", value: client.email)
                ClientDivider()
                ClientFieldRow(label: "Payment terms", value: "\(client.defaultTermsDays) days")
                ClientDivider()
                ClientFieldRow(label: "Payment method", value: resolvedPaymentMethodTitle)
            }
            .billbiSurface()
        }
    }
}

struct ClientInfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.xs) {
            Text(title)
                .font(BillbiTypography.micro)
                .foregroundStyle(BillbiColor.textMuted)
                .textCase(.uppercase)
            Text(value)
                .font(BillbiTypography.body.monospacedDigit().weight(.medium))
                .foregroundStyle(BillbiColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BillbiSpacing.md)
        .billbiSurface()
    }
}

struct ClientFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: BillbiSpacing.lg) {
            Text(label)
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(BillbiTypography.body)
                .foregroundStyle(BillbiColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BillbiSpacing.md)
    }
}

struct ClientEditableFieldRow<Content: View>: View {
    let label: String
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: BillbiSpacing.lg) {
            Text(label)
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 140, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(BillbiSpacing.md)
    }
}

struct ClientDivider: View {
    var body: some View {
        Divider()
            .overlay(BillbiColor.border)
    }
}
