import SwiftUI

struct CurrencyAmountField: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let currencyCode: String

    init(_ title: LocalizedStringKey, value: Binding<Double>, currencyCode: String) {
        self.title = title
        _value = value
        self.currencyCode = currencyCode
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: PikaSpacing.sm) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...2)))
                    .labelsHidden()
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 72, idealWidth: 86, maxWidth: 120)

                if !currencyLabel.isEmpty {
                    Text(currencyLabel)
                        .foregroundStyle(PikaColor.textSecondary)
                }
            }
        }
    }

    private var currencyLabel: String {
        currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
