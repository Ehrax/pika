import SwiftUI

struct ProjectEditorSheet: View {
    let project: WorkspaceProject
    let clients: [WorkspaceClient]
    let onCancel: () -> Void
    let onSave: (WorkspaceProjectUpdateDraft) -> Void

    @State private var name: String
    @State private var clientID: WorkspaceClient.ID?
    @State private var currencyCode: String

    init(
        project: WorkspaceProject,
        clients: [WorkspaceClient],
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceProjectUpdateDraft) -> Void
    ) {
        self.project = project
        self.clients = clients
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: project.name)
        _clientID = State(initialValue: project.clientID
            ?? clients.first(where: { $0.name == project.clientName })?.id
            ?? clients.first?.id)
        _currencyCode = State(initialValue: CurrencyTextFormatting.normalizedInput(project.currencyCode))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                BillbiInputSheetSection(title: "Project") {
                    BillbiInputSheetFieldRow(label: "Client") {
                        Picker("Client", selection: $clientID) {
                            if let clientID, !clients.contains(where: { $0.id == clientID }) {
                                Text(project.clientName).tag(Optional(clientID))
                            }

                            ForEach(clients) { client in
                                Text(client.name).tag(Optional(client.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    BillbiInputSheetDivider()
                    BillbiInputSheetFieldRow(label: "Project name") {
                        TextField("Project name", text: $name)
                            .textFieldStyle(.billbiInput)
                    }
                    BillbiInputSheetDivider()
                    BillbiInputSheetFieldRow(label: "Currency") {
                        CurrencyCodeField("Currency", text: $currencyCode)
                    }
                }
            }
            .padding(BillbiSpacing.md)

            Divider()

            HStack {
                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.billbiAction(.destructive))

                Spacer()

                Button {
                    guard let clientID else { return }
                    onSave(WorkspaceProjectUpdateDraft(
                        name: name,
                        clientID: clientID,
                        currencyCode: CurrencyTextFormatting.normalizedInput(currencyCode)
                    ))
                } label: {
                    Label("Save Project", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.billbiAction(.primary))
                .disabled(!canSave)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 280)
        .background(BillbiColor.background)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && clientID != nil
            && !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

}
