import Foundation

extension BusinessProfileProjection {
    var defaultPaymentMethod: WorkspacePaymentMethod? {
        if let defaultPaymentMethodID,
           let method = paymentMethods.first(where: { $0.id == defaultPaymentMethodID }) {
            return method
        }

        return paymentMethods.sorted(by: { $0.sortOrder < $1.sortOrder }).first
    }
}
