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
        _currencyCode = State(initialValue: CurrencyTextFormatting.normalizedInput(project.currencyCode))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                PikaInputSheetSection(title: "Project") {
                    PikaInputSheetFieldRow(label: "Project name") {
                        TextField("Project name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    PikaInputSheetDivider()
                    PikaInputSheetFieldRow(label: "Client") {
                        Picker("Client", selection: $clientName) {
                            if !clients.contains(where: { $0.name == clientName }) {
                                Text(clientName).tag(clientName)
                            }

                            ForEach(clients) { client in
                                Text(client.name).tag(client.name)
                            }
                        }
                        .labelsHidden()
                    }
                    PikaInputSheetDivider()
                    PikaInputSheetFieldRow(label: "Currency") {
                        CurrencyCodeField("Currency", text: $currencyCode)
                    }
                }
            }
            .padding(PikaSpacing.md)

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
                    onSave(WorkspaceProjectUpdateDraft(
                        name: name,
                        clientName: clientName,
                        currencyCode: CurrencyTextFormatting.normalizedInput(currencyCode)
                    ))
                } label: {
                    Label("Save Project", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 280)
        .background(PikaColor.background)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
