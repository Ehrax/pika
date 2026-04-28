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
            Form {
                Section("Bucket") {
                    TextField("Bucket name", text: $name)
                    CurrencyAmountField("Hourly rate", value: $hourlyRate, currencyCode: currencyCode)
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
                    onSave(WorkspaceBucketDraft(
                        name: name,
                        hourlyRateMinorUnits: max(Int((hourlyRate * 100).rounded()), 0)
                    ))
                } label: {
                    Label(saveLabel, systemImage: saveSystemImage)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.pikaAction(.primary))
                .disabled(!canSave)
            }
            .padding(PikaSpacing.md)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 260)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hourlyRate > 0
    }
}
