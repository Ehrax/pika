import SwiftUI

struct ClientDetailHeader: View {
    let client: WorkspaceClient

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                Text(client.name)
                    .font(PikaTypography.display)
                    .foregroundStyle(PikaColor.textPrimary)
                Text(client.email)
                    .font(PikaTypography.body)
                    .foregroundStyle(PikaColor.textSecondary)
            }

            Spacer()

            HStack(spacing: PikaSpacing.sm) {
                StatusBadge(client.isArchived ? .neutral : .success, title: client.isArchived ? "Archived" : "Active")
            }
        }
    }
}

struct ClientDetailBillingSection: View {
    @Binding var draft: WorkspaceClientDraft
    @Binding var billingAddress: BillingAddressComponents
    let hasChanges: Bool
    let saveFailure: ClientSaveFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            SectionHeader(title: "Billing details", detail: hasChanges ? "Unsaved changes" : "Saved")

            VStack(spacing: 0) {
                ClientEditableFieldRow(label: "Name") {
                    TextField("Name", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                }
                ClientDivider()
                ClientEditableFieldRow(label: "Email") {
                    TextField("Billing email", text: $draft.email)
                        .textFieldStyle(.roundedBorder)
                }
                ClientDivider()
                ClientEditableFieldRow(label: "Billing address", alignment: .top) {
                    VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                        TextField("Street and number", text: $billingAddress.street)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: PikaSpacing.sm) {
                            TextField("Postal code", text: $billingAddress.postalCode)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120)
                            TextField("City", text: $billingAddress.city)
                                .textFieldStyle(.roundedBorder)
                            TextField("Country", text: $billingAddress.country)
                                .textFieldStyle(.roundedBorder)
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
                            .font(PikaTypography.body.monospacedDigit())
                    }
                }

                if let saveFailure {
                    ClientDivider()
                    Text(saveFailure.message)
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.danger)
                        .padding(PikaSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .pikaSurface()
        }
    }
}

struct ClientDetailInvoiceDefaultsSection: View {
    let client: WorkspaceClient

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            SectionHeader(title: "Invoice defaults", detail: "Client")

            VStack(spacing: 0) {
                ClientFieldRow(label: "Recipient", value: client.name)
                ClientDivider()
                ClientFieldRow(label: "Billing email", value: client.email)
                ClientDivider()
                ClientFieldRow(label: "Payment terms", value: "\(client.defaultTermsDays) days")
            }
            .pikaSurface()
        }
    }
}

struct ClientInfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.xs) {
            Text(title)
                .font(PikaTypography.micro)
                .foregroundStyle(PikaColor.textMuted)
                .textCase(.uppercase)
            Text(value)
                .font(PikaTypography.body.monospacedDigit().weight(.medium))
                .foregroundStyle(PikaColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PikaSpacing.md)
        .pikaSurface()
    }
}

struct ClientFieldRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: PikaSpacing.lg) {
            Text(label)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(PikaTypography.body)
                .foregroundStyle(PikaColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PikaSpacing.md)
    }
}

struct ClientEditableFieldRow<Content: View>: View {
    let label: String
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: PikaSpacing.lg) {
            Text(label)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 140, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PikaSpacing.md)
    }
}

struct ClientDivider: View {
    var body: some View {
        Divider()
            .overlay(PikaColor.border)
    }
}
