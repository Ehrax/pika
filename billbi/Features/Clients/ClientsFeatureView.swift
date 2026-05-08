import SwiftUI

enum ClientRowHitTarget: Equatable {
    case fullCell
}

struct ClientRowHitTargetPolicy: Equatable {
    static let hitTarget: ClientRowHitTarget = .fullCell
}

struct ClientsFeatureView: View {
    let workspace: WorkspaceSnapshot
    @Environment(\.workspaceStore) private var workspaceStore
    @State private var selectedClientID: WorkspaceClient.ID?
    @State private var showsCreateClient = false
    @State private var creationFailure: ClientCreationFailure?
    @State private var listActionFailure: ClientActionFailure?
    @State private var showsArchiveClientConfirmation = false
    @State private var showsDeleteClientConfirmation = false
    @State private var clientPendingListActionID: WorkspaceClient.ID?

    private var selectedClient: WorkspaceClient? {
        workspace.clients.first { $0.id == selectedClientID } ?? workspace.clients.first
    }

    var body: some View {
        ResizableDetailSplitView {
            ClientListColumn(
                clients: workspace.clients,
                linkedProjectCountsByClientID: linkedProjectCountsByClientID,
                selectedClientID: selectedClientID ?? workspace.clients.first?.id,
                onSelect: { selectedClientID = $0 },
                onCreateClient: { showsCreateClient = true },
                onArchiveClient: archiveClientFromList,
                onRestoreClient: restoreClientFromList,
                onDeleteClient: deleteClientFromList
            )
        } detail: {
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
        .background(BillbiColor.background)
        .navigationTitle(navigationTitle)
        .toolbar {
            #if !os(macOS)
            Button {
                showsCreateClient = true
            } label: {
                Label("New Client", systemImage: "plus")
            }
            .help("Create a client")
            #endif
        }
        .sheet(isPresented: $showsCreateClient) {
            CreateClientSheet(
                defaultTermsDays: workspace.businessProfile.defaultTermsDays,
                onCancel: { showsCreateClient = false },
                onSave: createClient
            )
        }
        .alert(item: $creationFailure) { failure in
            Alert(
                title: Text("Client Creation Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(item: $listActionFailure) { failure in
            Alert(
                title: Text("Client Action Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Archive this client?",
            isPresented: $showsArchiveClientConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Client", role: .destructive) {
                archivePendingClient()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived clients stay available for history, but must be archived before deletion.")
        }
        .confirmationDialog(
            "Delete this client?",
            isPresented: $showsDeleteClientConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Client", role: .destructive) {
                deletePendingClient()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleted clients are removed permanently and cannot be restored.")
        }
        .onAppear {
            selectedClientID = selectedClientID ?? workspace.clients.first?.id
            AppTelemetry.clientsLoaded(clientCount: workspace.clients.count)
        }
        .accessibilityIdentifier("ClientsView")
    }

    private func createClient(_ draft: WorkspaceClientDraft) {
        do {
            let client = try workspaceStore.createClient(draft)
            selectedClientID = client.id
            showsCreateClient = false
        } catch {
            creationFailure = ClientCreationFailure(message: error.localizedDescription)
        }
    }

    private var navigationTitle: String {
        #if os(macOS)
        ""
        #else
        "Clients"
        #endif
    }

    private var linkedProjectCountsByClientID: [WorkspaceClient.ID: Int] {
        Dictionary(
            uniqueKeysWithValues: workspace.clients.map { client in
                let count = workspace.projects.filter { $0.clientID == client.id }.count
                return (client.id, count)
            }
        )
    }

    private func archiveClientFromList(_ clientID: WorkspaceClient.ID) {
        clientPendingListActionID = clientID
        showsArchiveClientConfirmation = true
    }

    private func restoreClientFromList(_ clientID: WorkspaceClient.ID) {
        do {
            try workspaceStore.restoreClient(clientID: clientID)
        } catch {
            listActionFailure = ClientActionFailure(message: String(localized: "Client could not be restored."))
        }
    }

    private func deleteClientFromList(_ clientID: WorkspaceClient.ID) {
        clientPendingListActionID = clientID
        showsDeleteClientConfirmation = true
    }

    private func performArchiveClientFromList(_ clientID: WorkspaceClient.ID) {
        do {
            try workspaceStore.archiveClient(clientID: clientID)
        } catch {
            listActionFailure = ClientActionFailure(message: String(localized: "Client could not be archived."))
        }
    }

    private func performDeleteClientFromList(_ clientID: WorkspaceClient.ID) {
        do {
            try workspaceStore.removeClient(clientID: clientID)
            if selectedClientID == clientID {
                selectedClientID = workspaceStore.workspace.clients.first?.id
            }
        } catch WorkspaceStoreError.clientHasLinkedProjects {
            listActionFailure = ClientActionFailure(
                message: String(localized: "Clients with linked projects cannot be deleted. Archive can still be used.")
            )
        } catch WorkspaceStoreError.clientNotArchived {
            listActionFailure = ClientActionFailure(message: String(localized: "Archive this client before deleting."))
        } catch {
            listActionFailure = ClientActionFailure(message: String(localized: "Client could not be deleted."))
        }
    }

    private func archivePendingClient() {
        guard let clientID = clientPendingListActionID else { return }
        performArchiveClientFromList(clientID)
        clientPendingListActionID = nil
    }

    private func deletePendingClient() {
        guard let clientID = clientPendingListActionID else { return }
        performDeleteClientFromList(clientID)
        clientPendingListActionID = nil
    }
}

struct ClientCreationFailure: Identifiable {
    let id = UUID()
    let message: String
}

struct ClientActionFailure: Identifiable {
    let id = UUID()
    let message: String
}

extension WorkspaceClientDraft {
    init(client: WorkspaceClient) {
        self.init(
            name: client.name,
            email: client.email,
            billingAddress: client.billingAddress,
            defaultTermsDays: client.defaultTermsDays,
            preferredPaymentMethodID: client.preferredPaymentMethodID
        )
    }
}
