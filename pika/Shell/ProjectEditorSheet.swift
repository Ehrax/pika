import SwiftUI

struct ProjectEditorSheet: View {
    let project: WorkspaceProject
    let clients: [WorkspaceClient]
    let onCancel: () -> Void
    let onSave: (WorkspaceProjectUpdateDraft) -> Void

    @State private var name: String
    @State private var clientName: String
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
        _clientName = State(initialValue: project.clientName)
        _currencyCode = State(initialValue: project.currencyCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Project") {
                    TextField("Project name", text: $name)

                    Picker("Client", selection: $clientName) {
                        if !clients.contains(where: { $0.name == clientName }) {
                            Text(clientName).tag(clientName)
                        }

                        ForEach(clients) { client in
                            Text(client.name).tag(client.name)
                        }
                    }

                    TextField("Currency", text: $currencyCode)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onSave(WorkspaceProjectUpdateDraft(
                        name: name,
                        clientName: clientName,
                        currencyCode: currencyCode
                    ))
                } label: {
                    Label("Save Project", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 280)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
