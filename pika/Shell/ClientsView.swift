import SwiftUI

enum ClientRowHitTarget: Equatable {
    case fullCell
}

struct ClientRowHitTargetPolicy: Equatable {
    static let hitTarget: ClientRowHitTarget = .fullCell
}

struct ClientsView: View {
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
        .background(PikaColor.background)
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
                let count = workspace.projects.filter { $0.clientName == client.name }.count
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
            listActionFailure = ClientActionFailure(message: "Client could not be restored.")
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
            listActionFailure = ClientActionFailure(message: "Client could not be archived.")
        }
    }

    private func performDeleteClientFromList(_ clientID: WorkspaceClient.ID) {
        do {
            try workspaceStore.removeClient(clientID: clientID)
            if selectedClientID == clientID {
                selectedClientID = workspaceStore.workspace.clients.first?.id
            }
        } catch WorkspaceStoreError.clientHasLinkedProjects {
            listActionFailure = ClientActionFailure(message: "Clients with linked projects cannot be deleted. Archive can still be used.")
        } catch WorkspaceStoreError.clientNotArchived {
            listActionFailure = ClientActionFailure(message: "Archive this client before deleting.")
        } catch {
            listActionFailure = ClientActionFailure(message: "Client could not be deleted.")
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

private struct ClientListColumn: View {
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
            .buttonStyle(PikaColumnHeaderIconButtonStyle())
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

private struct ClientCreationFailure: Identifiable {
    let id = UUID()
    let message: String
}

private struct CreateClientSheet: View {
    let onCancel: () -> Void
    let onSave: (WorkspaceClientDraft) -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var billingAddress = ""
    @State private var defaultTermsDaysValue: Int

    init(
        defaultTermsDays: Int,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceClientDraft) -> Void
    ) {
        self.onCancel = onCancel
        self.onSave = onSave
        _defaultTermsDaysValue = State(initialValue: defaultTermsDays)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Client") {
                    TextField("Name", text: $name)
                    TextField("Billing email", text: $email)
                    TextField("Billing address", text: $billingAddress, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Invoice defaults") {
                    Stepper(
                        value: $defaultTermsDaysValue,
                        in: 1...120
                    ) {
                        LabeledContent("Payment terms", value: "\(defaultTermsDaysValue) days")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.pikaAction(.destructive))

                Spacer()

                Button {
                    onSave(WorkspaceClientDraft(
                        name: name,
                        email: email,
                        billingAddress: billingAddress,
                        defaultTermsDays: defaultTermsDaysValue
                    ))
                } label: {
                    Label("Create Client", systemImage: "person.crop.circle.badge.plus")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 360)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !billingAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && defaultTermsDaysValue > 0
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

            if client.isArchived {
                StatusBadge(.neutral, title: "Archived")
            } else {
                Text("\(client.defaultTermsDays)d")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PikaColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, 10)
        .pikaSecondarySidebarRow(isSelected: isSelected)
    }
}

private struct ClientDetailSurface: View {
    let client: WorkspaceClient
    @Environment(\.workspaceStore) private var workspaceStore
    @State private var draft: WorkspaceClientDraft
    @State private var savedDraft: WorkspaceClientDraft
    @State private var saveFailure: ClientSaveFailure?
    @State private var showsArchiveClientConfirmation = false
    @State private var showsDeleteClientConfirmation = false
    @State private var clientActionFailure: ClientActionFailure?

    init(client: WorkspaceClient) {
        self.client = client
        let draft = WorkspaceClientDraft(client: client)
        _draft = State(initialValue: draft)
        _savedDraft = State(initialValue: draft)
    }

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

                    HStack(spacing: PikaSpacing.sm) {
                        StatusBadge(client.isArchived ? .neutral : .success, title: client.isArchived ? "Archived" : "Active")
                    }
                }

                HStack(spacing: PikaSpacing.md) {
                    ClientInfoTile(title: "Projects", value: "\(projectCount) linked")
                }

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
                        ClientEditableFieldRow(label: "Billing address") {
                            TextField("Billing address", text: $draft.billingAddress, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
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
        workspaceStore.workspace.projects.filter { $0.clientName == client.name }.count
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
            saveFailure = nil
        } catch WorkspaceStoreError.invalidClient {
            saveFailure = ClientSaveFailure(message: "Name, billing email, billing address, and payment terms are required.")
        } catch {
            saveFailure = ClientSaveFailure(message: "Client could not be saved.")
        }
    }

    private func revertChanges() {
        draft = savedDraft
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
                .font(PikaTypography.body.monospacedDigit().weight(.medium))
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

private struct ClientEditableFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PikaSpacing.lg) {
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

private struct ClientDivider: View {
    var body: some View {
        Divider()
            .overlay(PikaColor.border)
    }
}

private struct ClientSaveFailure: Identifiable {
    let id = UUID()
    let message: String
}

private struct ClientActionFailure: Identifiable {
    let id = UUID()
    let message: String
}

private extension WorkspaceClientDraft {
    init(client: WorkspaceClient) {
        self.init(
            name: client.name,
            email: client.email,
            billingAddress: client.billingAddress,
            defaultTermsDays: client.defaultTermsDays
        )
    }
}
