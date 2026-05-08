import Foundation

extension BusinessProfileProjection {
    var defaultPaymentMethod: WorkspacePaymentMethod? {
        if let defaultPaymentMethodID,
           let method = paymentMethods.first(where: { $0.id == defaultPaymentMethodID }) {
            return method
        }

        return paymentMethods.sorted(by: { $0.sortOrder < $1.sortOrder }).first
    }

    func paymentMethod(id: UUID?) -> WorkspacePaymentMethod? {
        guard let id else { return nil }
        return paymentMethods.first(where: { $0.id == id })
    }

    func resolvedPaymentMethod(
        invoiceOverrideID: UUID?,
        clientPreferredID: UUID?
    ) -> WorkspacePaymentMethod? {
        if let method = paymentMethod(id: invoiceOverrideID) {
            return method
        }
        if let method = paymentMethod(id: clientPreferredID) {
            return method
        }
        return defaultPaymentMethod
    }
}
