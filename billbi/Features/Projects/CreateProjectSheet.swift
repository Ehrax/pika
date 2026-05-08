import SwiftUI

struct CreateProjectSheet: View {
    let clients: [WorkspaceClient]
    let defaultCurrencyCode: String
    let onCancel: () -> Void
    let onSave: (WorkspaceProjectDraft) -> Void

    @State private var name = ""
    @State private var clientID: WorkspaceClient.ID?
    @State private var currencyCode: String
    @State private var firstBucketName = "MVP"
    @State private var hourlyRate = 80.0

    init(
        clients: [WorkspaceClient],
        defaultCurrencyCode: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceProjectDraft) -> Void
    ) {
        self.clients = clients
        self.defaultCurrencyCode = defaultCurrencyCode
        self.onCancel = onCancel
        self.onSave = onSave
        _clientID = State(initialValue: clients.first?.id)
        _currencyCode = State(initialValue: defaultCurrencyCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                    BillbiInputSheetSection(title: "Project") {
                        BillbiInputSheetFieldRow(label: "Client") {
                            if clients.isEmpty {
                                Text("Create a client first")
                                    .foregroundStyle(BillbiColor.textMuted)
                            } else {
                                Picker("Client", selection: $clientID) {
                                    ForEach(clients) { client in
                                        Text(client.name).tag(Optional(client.id))
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
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

                    BillbiInputSheetSection(title: "Starter bucket") {
                        BillbiInputSheetFieldRow(label: "Bucket name") {
                            TextField("Bucket name", text: $firstBucketName)
                                .textFieldStyle(.billbiInput)
                        }
                        BillbiInputSheetDivider()
                        BillbiInputSheetFieldRow(label: "Hourly rate") {
                            CurrencyAmountField("Hourly rate", value: $hourlyRate, currencyCode: currencyCode)
                        }
                    }
                }
                .padding(BillbiSpacing.md)
            }

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
                    onSave(WorkspaceProjectDraft(
                        name: name,
                        clientID: clientID,
                        currencyCode: CurrencyTextFormatting.normalizedInput(currencyCode),
                        firstBucketName: firstBucketName,
                        hourlyRateMinorUnits: max(Int((hourlyRate * 100).rounded()), 0)
                    ))
                } label: {
                    Label("Create Project", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.billbiAction(.primary))
                .disabled(!canSave)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 360)
        .background(BillbiColor.background)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && clientID != nil
            && !currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && hourlyRate > 0
    }

}
