import SwiftUI

struct ClientListColumn: View {
    let clients: [WorkspaceClient]
    let linkedProjectCountsByClientID: [WorkspaceClient.ID: Int]
    let selectedClientID: WorkspaceClient.ID?
    let onSelect: (WorkspaceClient.ID) -> Void
    let onCreateClient: () -> Void
    let onArchiveClient: (WorkspaceClient.ID) -> Void
    let onRestoreClient: (WorkspaceClient.ID) -> Void
    let onDeleteClient: (WorkspaceClient.ID) -> Void

    var body: some View {
        PikaSecondarySidebarColumn(
            title: "Clients",
            subtitle: "\(clients.count) billing profiles",
            sectionTitle: "All Clients",
            wrapsContentInScrollView: false
        ) {
            Button {
                onCreateClient()
            } label: {
                Label("Create a client", systemImage: "plus")
            }
            .buttonStyle(PikaColumnHeaderIconButtonStyle(foreground: PikaColor.actionAccent))
            .help("Create a client")
        } controls: {
            EmptyView()
        } content: {
            VStack(spacing: 0) {
                Divider()
                clientList
                    .padding(.top, PikaSpacing.md)
            }
        }
    }

    private var clientList: some View {
        List {
            ForEach(orderedClients) { client in
                Button {
                    onSelect(client.id)
                } label: {
                    ClientRow(client: client, isSelected: client.id == selectedClientID)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 1, leading: PikaSpacing.sm, bottom: 1, trailing: PikaSpacing.sm))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    clientSwipeActions(for: client)
                }
                .contextMenu {
                    clientMenuActions(for: client)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(PikaColor.surface)
    }

    private var orderedClients: [WorkspaceClient] {
        clients
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isArchived != rhs.element.isArchived {
                    return !lhs.element.isArchived
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func linkedProjectCount(for client: WorkspaceClient) -> Int {
        linkedProjectCountsByClientID[client.id] ?? 0
    }

    @ViewBuilder
    private func clientSwipeActions(for client: WorkspaceClient) -> some View {
        if client.isArchived {
            if linkedProjectCount(for: client) == 0 {
                Button(role: .destructive) {
                    onDeleteClient(client.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .tint(PikaColor.danger)
            }
        } else {
            Button {
                onArchiveClient(client.id)
            } label: {
                Label("Archive", systemImage: "archivebox")
                    .labelStyle(.iconOnly)
            }
            .tint(PikaColor.warning)
        }
    }

    @ViewBuilder
    private func clientMenuActions(for client: WorkspaceClient) -> some View {
        if client.isArchived {
            Button {
                onRestoreClient(client.id)
            } label: {
                Label("Restore Client", systemImage: "arrow.uturn.backward")
            }

            Button(role: .destructive) {
                onDeleteClient(client.id)
            } label: {
                Label("Delete Client", systemImage: "trash")
            }
            .disabled(linkedProjectCount(for: client) > 0)
        } else {
            Button {
                onArchiveClient(client.id)
            } label: {
                Label("Archive Client", systemImage: "archivebox")
            }
        }
    }
}
