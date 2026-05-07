import SwiftUI

struct CreateBucketSheet: View {
    let defaultRateMinorUnits: Int
    let currencyCode: String
    let initialName: String
    let saveLabel: String
    let saveSystemImage: String
    let onCancel: () -> Void
    let onSave: (WorkspaceBucketDraft) -> Void

    @State private var name: String
    @State private var hourlyRate: Double

    init(
        defaultRateMinorUnits: Int,
        currencyCode: String,
        initialName: String = "",
        saveLabel: String = "Create Bucket",
        saveSystemImage: String = "tray.full",
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceBucketDraft) -> Void
    ) {
        self.defaultRateMinorUnits = defaultRateMinorUnits
        self.currencyCode = currencyCode
        self.initialName = initialName
        self.saveLabel = saveLabel
        self.saveSystemImage = saveSystemImage
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _hourlyRate = State(initialValue: Double(defaultRateMinorUnits) / 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                BillbiInputSheetSection(title: "Bucket") {
                    BillbiInputSheetFieldRow(label: "Bucket name") {
                        TextField("Bucket name", text: $name)
                            .textFieldStyle(.billbiInput)
                    }
                    BillbiInputSheetDivider()
                    BillbiInputSheetFieldRow(label: "Hourly rate") {
                        CurrencyAmountField("Hourly rate", value: $hourlyRate, currencyCode: currencyCode)
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
                    onSave(WorkspaceBucketDraft(
                        name: name,
                        hourlyRateMinorUnits: max(Int((hourlyRate * 100).rounded()), 0)
                    ))
                } label: {
                    Label(saveLabel, systemImage: saveSystemImage)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.billbiAction(.primary))
                .disabled(!canSave)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 260)
        .background(BillbiColor.background)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hourlyRate > 0
    }
}
