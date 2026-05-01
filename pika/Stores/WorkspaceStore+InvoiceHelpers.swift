import Foundation

extension WorkspaceStore {
    func nextInvoiceNumber(issueDate: Date) -> String {
        let year = Calendar.pikaStoreGregorian.component(.year, from: issueDate)
        return InvoiceNumberFormatter(prefix: workspace.businessProfile.invoicePrefix).string(
            year: year,
            sequence: workspace.businessProfile.nextInvoiceNumber
        )
    }

    func snapshotClient(
        id clientID: UUID? = nil,
        named clientName: String,
        draft: InvoiceFinalizationDraft
    ) -> WorkspaceClient {
        let matchedClient = workspace.clients.firstMatching(id: clientID, name: clientName)
        let resolvedClientID = matchedClient?.id ?? clientID ?? UUID()
        let termsDays = invoiceTermsDays(for: matchedClient)

        return WorkspaceClient(
            id: resolvedClientID,
            name: draft.recipientName,
            email: draft.recipientEmail,
            billingAddress: draft.recipientBillingAddress,
            defaultTermsDays: termsDays,
            isArchived: false
        )
    }

    func invoiceTermsDays(for client: WorkspaceClient?) -> Int {
        guard let client,
              Self.clientHasExplicitInvoiceDefaults(client)
        else {
            return workspace.businessProfile.defaultTermsDays
        }

        return client.defaultTermsDays
    }

    private static func clientHasExplicitInvoiceDefaults(_ client: WorkspaceClient) -> Bool {
        let email = client.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = client.billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return !email.isEmpty || !billingAddress.isEmpty
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
