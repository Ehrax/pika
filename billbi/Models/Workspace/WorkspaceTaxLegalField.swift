import Foundation

enum TaxLegalFieldPlacement: String, Codable, CaseIterable, Equatable {
    case senderDetails
    case recipientDetails
    case footer
    case hidden
}

struct WorkspaceTaxLegalField: Codable, Equatable, Identifiable {
    let id: UUID
    var label: String
    var value: String
    var placement: TaxLegalFieldPlacement
    var isVisible: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        label: String,
        value: String,
        placement: TaxLegalFieldPlacement = .senderDetails,
        isVisible: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.placement = placement
        self.isVisible = isVisible
        self.sortOrder = sortOrder
    }

    var isRenderable: Bool {
        isVisible && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Array where Element == WorkspaceTaxLegalField {
    static func migratedSenderFields(
        taxIdentifier: String,
        economicIdentifier: String
    ) -> [WorkspaceTaxLegalField] {
        var fields: [WorkspaceTaxLegalField] = []
        let tax = taxIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let economic = economicIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        if !tax.isEmpty {
            fields.append(WorkspaceTaxLegalField(
                id: UUID(uuidString: "0D2C4B03-3E4E-4D7C-9A7A-9D6E0C7F1A11")!,
                label: "Steuernummer",
                value: tax,
                placement: .senderDetails,
                sortOrder: 0
            ))
        }

        if !economic.isEmpty {
            fields.append(WorkspaceTaxLegalField(
                id: UUID(uuidString: "0D2C4B03-3E4E-4D7C-9A7A-9D6E0C7F1A12")!,
                label: "Wirtschafts-IdNr",
                value: economic,
                placement: .senderDetails,
                sortOrder: fields.count
            ))
        }

        return fields
    }
}
