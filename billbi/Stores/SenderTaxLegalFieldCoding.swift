import Foundation

enum SenderTaxLegalFieldCoding {
    static func encode(_ fields: [WorkspaceTaxLegalField]) -> String {
        guard let data = try? JSONEncoder().encode(fields),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    static func decode(_ value: String) -> [WorkspaceTaxLegalField] {
        guard let data = value.data(using: .utf8),
              let fields = try? JSONDecoder().decode([WorkspaceTaxLegalField].self, from: data)
        else {
            return []
        }
        return fields
    }
}
