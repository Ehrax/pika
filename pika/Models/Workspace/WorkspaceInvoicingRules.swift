import Foundation

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
