import Foundation

extension Collection where Element == WorkspaceClient {
    func firstMatching(id clientID: UUID?, name clientName: String) -> WorkspaceClient? {
        first { client in
            if let clientID {
                return client.id == clientID
            }

            return client.name == clientName
        }
    }
}

extension WorkspaceClient {
    var hasExplicitInvoiceDefaults: Bool {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let billingAddress = billingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return !email.isEmpty || !billingAddress.isEmpty
    }
}

extension WorkspaceInvoice {
    static func normalizedNumberKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
