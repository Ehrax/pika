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
        HStack(spacing: BillbiSpacing.sm) {
            TextField("", value: $value, format: .number.precision(.fractionLength(0...2)))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(title)

            if !currencyLabel.isEmpty {
                Text(currencyLabel)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var currencyLabel: String {
        currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
