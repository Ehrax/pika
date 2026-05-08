import SwiftUI

struct CreateBucketSheet: View {
    let defaultRateMinorUnits: Int
    let currencyCode: String
    let initialName: String
    let initialBillingMode: WorkspaceBucketBillingMode
    let isBillingModeEditable: Bool
    let saveLabel: String
    let saveSystemImage: String
    let onCancel: () -> Void
    let onSave: (WorkspaceBucketDraft) -> Void

    @State private var name: String
    @State private var billingMode: WorkspaceBucketBillingMode
    @State private var hourlyRate: Double
    @State private var fixedAmount: Double
    @State private var retainerAmount: Double
    @State private var retainerPeriodLabel: String
    @State private var retainerIncludedHours: String
    @State private var retainerOverageRate: Double

    init(
        defaultRateMinorUnits: Int,
        currencyCode: String,
        initialName: String = "",
        initialBillingMode: WorkspaceBucketBillingMode = .hourly,
        initialFixedAmountMinorUnits: Int? = nil,
        initialRetainerAmountMinorUnits: Int? = nil,
        initialRetainerPeriodLabel: String = "",
        initialRetainerIncludedMinutes: Int? = nil,
        initialRetainerOverageRateMinorUnits: Int? = nil,
        isBillingModeEditable: Bool = true,
        saveLabel: String = "Create Bucket",
        saveSystemImage: String = "tray.full",
        onCancel: @escaping () -> Void,
        onSave: @escaping (WorkspaceBucketDraft) -> Void
    ) {
        self.defaultRateMinorUnits = defaultRateMinorUnits
        self.currencyCode = currencyCode
        self.initialName = initialName
        self.initialBillingMode = initialBillingMode
        self.isBillingModeEditable = isBillingModeEditable
        self.saveLabel = saveLabel
        self.saveSystemImage = saveSystemImage
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _billingMode = State(initialValue: initialBillingMode)
        _hourlyRate = State(initialValue: Double(defaultRateMinorUnits) / 100)
        _fixedAmount = State(initialValue: Double(initialFixedAmountMinorUnits ?? defaultRateMinorUnits) / 100)
        _retainerAmount = State(initialValue: Double(initialRetainerAmountMinorUnits ?? defaultRateMinorUnits) / 100)
        _retainerPeriodLabel = State(initialValue: initialRetainerPeriodLabel)
        _retainerIncludedHours = State(initialValue: initialRetainerIncludedMinutes.map { Self.hoursText(minutes: $0) } ?? "")
        _retainerOverageRate = State(initialValue: Double(initialRetainerOverageRateMinorUnits ?? defaultRateMinorUnits) / 100)
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
                    BillbiInputSheetFieldRow(label: "Billing mode") {
                        Picker("Billing mode", selection: $billingMode) {
                            ForEach(WorkspaceBucketBillingMode.allCases, id: \.self) { mode in
                                Text(mode.displayTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(!isBillingModeEditable)
                    }
                    BillbiInputSheetDivider()
                    modeFields
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
                    onSave(draft)
                } label: {
                    Label(saveLabel, systemImage: saveSystemImage)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.billbiAction(.primary))
                .disabled(!canSave)
            }
            .padding(BillbiSpacing.md)
        }
        .frame(minWidth: 460, idealWidth: 500, minHeight: 320)
        .background(BillbiColor.background)
    }

    @ViewBuilder
    private var modeFields: some View {
        switch billingMode {
        case .hourly:
            BillbiInputSheetFieldRow(label: "Hourly rate") {
                CurrencyAmountField("Hourly rate", value: $hourlyRate, currencyCode: currencyCode)
            }
        case .fixed:
            BillbiInputSheetFieldRow(label: "Fixed amount") {
                CurrencyAmountField("Fixed amount", value: $fixedAmount, currencyCode: currencyCode)
            }
        case .retainer:
            BillbiInputSheetFieldRow(label: "Retainer amount") {
                CurrencyAmountField("Retainer amount", value: $retainerAmount, currencyCode: currencyCode)
            }
            BillbiInputSheetDivider()
            BillbiInputSheetFieldRow(label: "Period") {
                TextField("Monthly", text: $retainerPeriodLabel)
                    .textFieldStyle(.billbiInput)
            }
            BillbiInputSheetDivider()
            BillbiInputSheetFieldRow(label: "Included hours") {
                TextField("Optional", text: $retainerIncludedHours)
                    .textFieldStyle(.billbiInput)
            }
            BillbiInputSheetDivider()
            BillbiInputSheetFieldRow(label: "Overage rate") {
                CurrencyAmountField("Overage rate", value: $retainerOverageRate, currencyCode: currencyCode)
            }
        }
    }

    private var draft: WorkspaceBucketDraft {
        WorkspaceBucketDraft(
            name: name,
            billingMode: billingMode,
            hourlyRateMinorUnits: max(Int((hourlyRate * 100).rounded()), 0),
            fixedAmountMinorUnits: max(Int((fixedAmount * 100).rounded()), 0),
            retainerAmountMinorUnits: max(Int((retainerAmount * 100).rounded()), 0),
            retainerPeriodLabel: retainerPeriodLabel,
            retainerIncludedMinutes: parsedIncludedMinutes,
            retainerOverageRateMinorUnits: max(Int((retainerOverageRate * 100).rounded()), 0)
        )
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        switch billingMode {
        case .hourly:
            return hourlyRate > 0
        case .fixed:
            return fixedAmount > 0
        case .retainer:
            return retainerAmount > 0 && parsedIncludedMinutes.map { $0 >= 0 } != false && retainerOverageRate >= 0
        }
    }

    private var parsedIncludedMinutes: Int? {
        let trimmed = retainerIncludedHours.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let hours = Double(normalized), hours >= 0 else { return -1 }
        return Int((hours * 60).rounded())
    }

    private static func hoursText(minutes: Int) -> String {
        let hours = Double(minutes) / 60
        return String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), hours)
    }
}
