import Foundation

enum PaymentMethodCoding {
    static func encode(_ methods: [WorkspacePaymentMethod]) -> String {
        guard let data = try? JSONEncoder().encode(methods),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    static func decode(_ value: String) -> [WorkspacePaymentMethod] {
        guard let data = value.data(using: .utf8),
              let methods = try? JSONDecoder().decode([WorkspacePaymentMethod].self, from: data)
        else {
            return []
        }
        return methods
    }

    static func encodeOptional(_ method: WorkspacePaymentMethod?) -> String {
        guard let method,
              let data = try? JSONEncoder().encode(method),
              let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return string
    }

    static func decodeOptional(_ value: String) -> WorkspacePaymentMethod? {
        guard !value.isEmpty,
              let data = value.data(using: .utf8),
              let method = try? JSONDecoder().decode(WorkspacePaymentMethod.self, from: data)
        else {
            return nil
        }
        return method
    }
}
