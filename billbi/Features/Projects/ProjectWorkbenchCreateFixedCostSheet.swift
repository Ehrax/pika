import SwiftUI

struct CreateFixedCostSheet: View {
    let currencyCode: String
    let onCancel: () -> Void
    let onSave: (WorkspaceFixedCostDraft) -> Void

    @State private var draftDate: Date
    @State private var description = ""
    @State private var amount = 50.0

    init(
        date: Date,
        currencyCode: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceFixedCostDraft) -> Void
    ) {
        self.currencyCode = currencyCode
        self.onCancel = onCancel
        self.onSave = onSave
        _draftDate = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                BillbiInputSheetSection(title: "Fixed cost") {
                    BillbiInputSheetFieldRow(label: "Date") {
                        DatePicker("", selection: $draftDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                    BillbiInputSheetDivider()
                    BillbiInputSheetFieldRow(label: "Description") {
                        TextField("Description", text: $description)
                            .textFieldStyle(.roundedBorder)
                    }
                    BillbiInputSheetDivider()
                    BillbiInputSheetFieldRow(label: "Amount") {
                        CurrencyAmountField("Amount", value: $amount, currencyCode: currencyCode)
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
                    onSave(WorkspaceFixedCostDraft(
                        date: draftDate,
                        description: description,
                        amountMinorUnits: max(Int((amount * 100).rounded()), 0)
                    ))
                } label: {
                    Label("Add Cost", systemImage: "plus.square")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.billbiAction(.primary))
                .disabled(!canSave)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 300)
        .background(BillbiColor.background)
    }

    private var canSave: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }
}
