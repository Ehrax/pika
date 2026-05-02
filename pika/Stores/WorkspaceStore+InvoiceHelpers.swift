import Foundation

extension WorkspaceStore {
    func nextInvoiceNumber(issueDate: Date) -> String {
        let year = Calendar.pikaStoreGregorian.component(.year, from: issueDate)
        return InvoiceNumberFormatter(prefix: workspace.businessProfile.invoicePrefix).string(
            year: year,
            sequence: workspace.businessProfile.nextInvoiceNumber
        )
    }

    func invoiceTermsDays(for client: WorkspaceClient?) -> Int {
        guard let client,
              client.hasExplicitInvoiceDefaults
        else {
            return workspace.businessProfile.defaultTermsDays
        }

        return client.defaultTermsDays
    }

    func defaultServicePeriod(for bucket: WorkspaceBucket?) -> String {
        guard let bucket else { return "" }

        let dates = bucket.timeEntries.map(\.date) + bucket.fixedCostEntries.map(\.date)
        guard let first = dates.min(), let last = dates.max() else {
            return ""
        }
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "de_DE")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "dd.MM.yyyy"
        if first == last {
            return dateFormatter.string(from: first)
        }

        return "\(dateFormatter.string(from: first)) - \(dateFormatter.string(from: last))"
    }
}
