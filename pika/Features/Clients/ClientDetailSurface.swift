import SwiftUI

struct ClientDetailSurface: View {
    let client: WorkspaceClient
    @Environment(\.workspaceStore) private var workspaceStore
    @State private var draft: WorkspaceClientDraft
    @State private var savedDraft: WorkspaceClientDraft
    @State private var billingAddress: BillingAddressComponents
    @State private var saveFailure: ClientSaveFailure?
    @State private var showsArchiveClientConfirmation = false
    @State private var showsDeleteClientConfirmation = false
    @State private var clientActionFailure: ClientActionFailure?

    init(client: WorkspaceClient) {
        self.client = client
        let draft = WorkspaceClientDraft(client: client)
        _draft = State(initialValue: draft)
        _savedDraft = State(initialValue: draft)
        _billingAddress = State(initialValue: BillingAddressComponents(rawAddress: draft.billingAddress))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                ClientDetailHeader(client: client)

                HStack(spacing: PikaSpacing.md) {
                    ClientInfoTile(title: "Projects", value: "\(projectCount) linked")
                }

                ClientDetailBillingSection(
                    draft: $draft,
                    billingAddress: $billingAddress,
                    hasChanges: hasChanges,
                    saveFailure: saveFailure
                )

                ClientDetailInvoiceDefaultsSection(client: client)
            }
            .padding(.horizontal, PikaSpacing.xl + PikaSpacing.md)
            .padding(.vertical, PikaSpacing.lg)
        }
        .background(PikaColor.background)
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button {
                        if client.isArchived {
                            restoreClient()
                        } else {
                            showsArchiveClientConfirmation = true
                        }
                    } label: {
                        Label(
                            client.isArchived ? "Restore Client" : "Archive Client",
                            systemImage: client.isArchived ? "arrow.uturn.backward" : "archivebox"
                        )
                    }
                    .tint(client.isArchived ? PikaColor.success : PikaColor.warning)

                    if client.isArchived {
                        Divider()

                        Button(role: .destructive) {
                            showsDeleteClientConfirmation = true
                        } label: {
                            Label("Delete Client", systemImage: "trash")
                        }
                        .disabled(!canDeleteClient)
                    }
                } label: {
                    Label("Client Actions", systemImage: "ellipsis.circle")
                }
                .help("Client actions")
                .tint(PikaColor.textPrimary)

                ControlGroup {
                    Button {
                        revertChanges()
                    } label: {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!hasChanges)
                    .help("Revert client changes")
                    .tint(PikaColor.textPrimary)

                    Button {
                        saveChanges()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .disabled(!hasChanges || !canSave)
                    .help("Save client")
                    .tint(PikaColor.textPrimary)
                }
            }
        }
        .confirmationDialog(
            "Archive this client?",
            isPresented: $showsArchiveClientConfirmation,
            titleVisibility: .visible
        ) {
            Button("Archive Client", role: .destructive) {
                archiveClient()
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
                deleteClient()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleted clients are removed permanently and cannot be restored.")
        }
        .alert(item: $clientActionFailure) { failure in
            Alert(
                title: Text("Client Action Failed"),
                message: Text(failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: client) { _, updatedClient in
            let updatedDraft = WorkspaceClientDraft(client: updatedClient)
            draft = updatedDraft
            savedDraft = updatedDraft
            billingAddress = BillingAddressComponents(rawAddress: updatedDraft.billingAddress)
            saveFailure = nil
        }
        .onChange(of: billingAddress) { _, newAddress in
            draft.billingAddress = newAddress.singleString
            saveFailure = nil
        }
    }

    private var hasChanges: Bool {
        draft != savedDraft
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.defaultTermsDays > 0
    }

    private var projectCount: Int {
        workspaceStore.workspace.projects.filter { $0.clientID == client.id }.count
    }

    private var canDeleteClient: Bool {
        client.isArchived && projectCount == 0
    }

    private func saveChanges() {
        do {
            let client = try workspaceStore.updateClient(clientID: client.id, draft)
            let updatedDraft = WorkspaceClientDraft(client: client)
            draft = updatedDraft
            savedDraft = updatedDraft
            billingAddress = BillingAddressComponents(rawAddress: updatedDraft.billingAddress)
            saveFailure = nil
        } catch WorkspaceStoreError.invalidClient {
            saveFailure = ClientSaveFailure(message: "Name, billing email, billing address, and payment terms are required.")
        } catch {
            saveFailure = ClientSaveFailure(message: "Client could not be saved.")
        }
    }

    private func revertChanges() {
        draft = savedDraft
        billingAddress = BillingAddressComponents(rawAddress: savedDraft.billingAddress)
        saveFailure = nil
    }

    private func archiveClient() {
        do {
            try workspaceStore.archiveClient(clientID: client.id)
        } catch {
            clientActionFailure = ClientActionFailure(message: "Client could not be archived.")
        }
    }

    private func restoreClient() {
        do {
            try workspaceStore.restoreClient(clientID: client.id)
        } catch {
            clientActionFailure = ClientActionFailure(message: "Client could not be restored.")
        }
    }

    private func deleteClient() {
        do {
            try workspaceStore.removeClient(clientID: client.id)
        } catch WorkspaceStoreError.clientHasLinkedProjects {
            clientActionFailure = ClientActionFailure(message: "Clients with linked projects cannot be deleted. Archive can still be used.")
        } catch WorkspaceStoreError.clientNotArchived {
            clientActionFailure = ClientActionFailure(message: "Archive this client before deleting.")
        } catch {
            clientActionFailure = ClientActionFailure(message: "Client could not be deleted.")
        }
    }
}

struct ClientSaveFailure: Identifiable {
    let id = UUID()
    let message: String
}
