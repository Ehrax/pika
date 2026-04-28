import SwiftUI

struct CreateFixedCostSheet: View {
    let date: Date
    let currencyCode: String
    let onCancel: () -> Void
    let onSave: (WorkspaceFixedCostDraft) -> Void

    @State private var description = ""
    @State private var amount = 50.0

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Fixed cost") {
                    DatePicker("Date", selection: .constant(date), displayedComponents: .date)
                        .disabled(true)
                    TextField("Description", text: $description)
                    CurrencyAmountField("Amount", value: $amount, currencyCode: currencyCode)
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
                    onSave(WorkspaceFixedCostDraft(
                        date: date,
                        description: description,
                        amountMinorUnits: max(Int((amount * 100).rounded()), 0)
                    ))
                } label: {
                    Label("Add Cost", systemImage: "plus.square")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
    }

    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }
}
