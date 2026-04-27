import Foundation

struct MoneyFormatting {
    private let formatter: NumberFormatter

    static func euros(locale: Locale = .current) -> MoneyFormatting {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "EUR"
        formatter.positiveFormat = "¤ #,##0.00"
        formatter.negativeFormat = "-¤ #,##0.00"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return MoneyFormatting(formatter: formatter)
    }

    func string(fromMinorUnits minorUnits: Int) -> String {
        let amount = Decimal(minorUnits) / Decimal(100)
        return formatter.string(from: amount as NSDecimalNumber) ?? "EUR \(amount)"
    }
}
