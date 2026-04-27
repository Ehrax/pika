import SwiftUI

enum ClientRowHitTarget: Equatable {
    case fullCell
}

struct ClientRowHitTargetPolicy: Equatable {
    static let hitTarget: ClientRowHitTarget = .fullCell
}

struct ClientsView: View {
    let workspace: WorkspaceSnapshot
    @State private var selectedClientID: WorkspaceClient.ID?

    private var selectedClient: WorkspaceClient? {
        workspace.clients.first { $0.id == selectedClientID } ?? workspace.clients.first
    }

    var body: some View {
        HStack(spacing: 0) {
            ClientListColumn(
                clients: workspace.clients,
                selectedClientID: selectedClientID ?? workspace.clients.first?.id,
                onSelect: { selectedClientID = $0 }
            )

            if let selectedClient {
                ClientDetailSurface(client: selectedClient)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    "No Clients",
                    systemImage: "person.2",
                    description: Text("Create a client before preparing invoices.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PikaColor.background)
        .navigationTitle("Clients")
        .toolbar {
            Button {
            } label: {
                Label("New Client", systemImage: "plus")
            }
            .disabled(true)
            .help("Client creation lands in a later task")
        }
        .onAppear {
            selectedClientID = selectedClientID ?? workspace.clients.first?.id
            AppTelemetry.clientsLoaded(clientCount: workspace.clients.count)
        }
        .accessibilityIdentifier("ClientsView")
    }
}

private struct ClientListColumn: View {
    let clients: [WorkspaceClient]
    let selectedClientID: WorkspaceClient.ID?
    let onSelect: (WorkspaceClient.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Clients")
                        .font(PikaTypography.micro)
                        .foregroundStyle(PikaColor.textMuted)
                        .textCase(.uppercase)
                    Text("\(clients.count) billing profiles")
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textSecondary)
                }

                Spacer()

                Button {
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(true)
                .help("Client creation lands in a later task")
            }
            .padding(PikaSpacing.md)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(clients) { client in
                        Button {
                            onSelect(client.id)
                        } label: {
                            ClientRow(client: client, isSelected: client.id == selectedClientID)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, PikaSpacing.sm)
                .padding(.bottom, PikaSpacing.md)
            }
        }
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background(PikaColor.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PikaColor.border)
                .frame(width: 1)
        }
    }
}

private struct ClientRow: View {
    let client: WorkspaceClient
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            Image(systemName: "building.2")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(PikaTypography.body.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(PikaColor.textPrimary)
                    .lineLimit(1)
                Text(client.email)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(client.defaultTermsDays)d")
                .font(.caption.monospacedDigit())
                .foregroundStyle(PikaColor.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, 10)
        .background(isSelected ? PikaColor.surfaceAlt : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? PikaColor.accent : Color.clear)
                .frame(width: 2)
        }
    }
}

private struct ClientDetailSurface: View {
    let client: WorkspaceClient

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
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

                    StatusBadge(.neutral, title: "Active")
                }

                HStack(spacing: PikaSpacing.md) {
                    ClientInfoTile(title: "Default terms", value: "\(client.defaultTermsDays) days")
                    ClientInfoTile(title: "Invoices", value: "Not connected")
                    ClientInfoTile(title: "Archive state", value: "Active")
                }

                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    SectionHeader(title: "Billing details", detail: "Read-only")

                    VStack(spacing: 0) {
                        ClientFieldRow(label: "Name", value: client.name)
                        ClientDivider()
                        ClientFieldRow(label: "Email", value: client.email)
                        ClientDivider()
                        ClientFieldRow(label: "Billing address", value: client.billingAddress)
                        ClientDivider()
                        ClientFieldRow(label: "Payment terms", value: "\(client.defaultTermsDays) days")
                    }
                    .pikaSurface()
                }

                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    SectionHeader(title: "Next", detail: "Coming later")
                    Text("Client editing, archiving, and invoice defaults are not connected yet.")
                        .font(PikaTypography.body)
                        .foregroundStyle(PikaColor.textSecondary)
                        .padding(PikaSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pikaSurface()
                }
            }
            .padding(.horizontal, PikaSpacing.xl)
            .padding(.vertical, PikaSpacing.lg)
        }
        .background(PikaColor.background)
    }
}

private struct ClientInfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.xs) {
            Text(title)
                .font(PikaTypography.micro)
                .foregroundStyle(PikaColor.textMuted)
                .textCase(.uppercase)
            Text(value)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(PikaColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PikaSpacing.md)
        .pikaSurface()
    }
}

private struct ClientFieldRow: View {
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

private struct ClientDivider: View {
    var body: some View {
        Divider()
            .overlay(PikaColor.border)
    }
}
