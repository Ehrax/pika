import Foundation

enum WorkspacePaymentMethodType: String, Codable, CaseIterable, Equatable {
    case sepaBankTransfer
    case internationalBankTransfer
    case paypal
    case wise
    case paymentLink
    case other
}

struct WorkspacePaymentMethod: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var type: WorkspacePaymentMethodType
    var placement: TaxLegalFieldPlacement
    var isVisible: Bool
    var sortOrder: Int
    var accountHolder: String
    var iban: String
    var bic: String
    var email: String
    var url: String
    var instructions: String

    init(
        id: UUID = UUID(),
        title: String,
        type: WorkspacePaymentMethodType,
        placement: TaxLegalFieldPlacement = .footer,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        accountHolder: String = "",
        iban: String = "",
        bic: String = "",
        email: String = "",
        url: String = "",
        instructions: String = ""
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.placement = placement
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.accountHolder = accountHolder
        self.iban = iban
        self.bic = bic
        self.email = email
        self.url = url
        self.instructions = instructions
    }

    var printableInstructions: String {
        switch type {
        case .sepaBankTransfer, .internationalBankTransfer:
            var lines: [String] = []
            if !accountHolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append(accountHolder.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if !iban.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("IBAN \(iban.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            if !bic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("BIC \(bic.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            if lines.isEmpty {
                return instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return lines.joined(separator: "\n")
        case .paypal, .wise:
            return email.trimmingCharacters(in: .whitespacesAndNewlines)
        case .paymentLink:
            return url.trimmingCharacters(in: .whitespacesAndNewlines)
        case .other:
            return instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var hasPrintableInstructions: Bool {
        !printableInstructions.isEmpty
    }

    var isSEPAEligible: Bool {
        type == .sepaBankTransfer && !iban.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Array where Element == WorkspacePaymentMethod {
    static func migratedFromLegacyPaymentDetails(
        _ paymentDetails: String,
        businessName: String
    ) -> [WorkspacePaymentMethod] {
        let trimmed = paymentDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let parsed = ParsedPaymentDetails(rawValue: trimmed)
        if !parsed.iban.isEmpty {
            return [
                WorkspacePaymentMethod(
                    id: UUID(uuidString: "3D410482-8EE9-4D6E-A8F5-6D7AF7458A11")!,
                    title: "SEPA bank transfer",
                    type: .sepaBankTransfer,
                    placement: .footer,
                    isVisible: true,
                    sortOrder: 0,
                    accountHolder: businessName,
                    iban: parsed.formattedIBAN,
                    bic: parsed.bic,
                    instructions: trimmed
                ),
            ]
        }

        return [
            WorkspacePaymentMethod(
                id: UUID(uuidString: "3D410482-8EE9-4D6E-A8F5-6D7AF7458A12")!,
                title: "Other",
                type: .other,
                placement: .footer,
                isVisible: true,
                sortOrder: 0,
                instructions: trimmed
            ),
        ]
    }
}
