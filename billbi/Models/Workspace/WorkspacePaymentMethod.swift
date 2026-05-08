import Foundation

enum WorkspacePaymentMethodType: String, Codable, CaseIterable, Equatable {
    case sepaBankTransfer
    case internationalBankTransfer
    case paypal
    case wise
    case paymentLink
    case other

    var displayName: String {
        switch self {
        case .sepaBankTransfer:
            String(localized: "SEPA bank transfer")
        case .internationalBankTransfer:
            String(localized: "International bank transfer")
        case .paypal:
            String(localized: "PayPal")
        case .wise:
            String(localized: "Wise")
        case .paymentLink:
            String(localized: "Payment link")
        case .other:
            String(localized: "Other")
        }
    }
}

struct WorkspacePaymentMethodValidation: Equatable {
    var blockingMessages: [String] = []
    var warningMessages: [String] = []

    var isValid: Bool {
        blockingMessages.isEmpty
    }
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
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedEmail.isEmpty {
                return trimmedEmail
            }
            if !trimmedURL.isEmpty {
                return trimmedURL
            }
            return instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        case .paymentLink:
            return url.trimmingCharacters(in: .whitespacesAndNewlines)
        case .other:
            return instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var hasPrintableInstructions: Bool {
        !printableInstructions.isEmpty
    }

    var validation: WorkspacePaymentMethodValidation {
        var result = WorkspacePaymentMethodValidation()
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIBAN = Self.normalizedIBAN(iban)
        let normalizedBIC = bic.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedTitle.isEmpty {
            result.blockingMessages.append(String(localized: "Payment method name is required."))
        }

        switch type {
        case .sepaBankTransfer:
            if normalizedIBAN.isEmpty {
                result.blockingMessages.append(String(localized: "IBAN is required for SEPA bank transfer."))
            } else if !Self.isValidIBAN(normalizedIBAN) {
                result.blockingMessages.append(String(localized: "IBAN is invalid."))
            }
            if !normalizedBIC.isEmpty, !Self.isValidBIC(normalizedBIC) {
                result.blockingMessages.append(String(localized: "BIC/SWIFT is invalid."))
            }
            if normalizedBIC.isEmpty {
                result.warningMessages.append(String(localized: "BIC/SWIFT is optional for SEPA, but useful for some clients."))
            }

        case .internationalBankTransfer:
            if normalizedIBAN.isEmpty, normalizedInstructions.isEmpty {
                result.blockingMessages.append(String(localized: "International transfer needs an IBAN/account number or instructions."))
            }
            if !normalizedIBAN.isEmpty, !Self.isValidIBAN(normalizedIBAN) {
                result.blockingMessages.append(String(localized: "IBAN is invalid."))
            }
            if !normalizedBIC.isEmpty, !Self.isValidBIC(normalizedBIC) {
                result.blockingMessages.append(String(localized: "BIC/SWIFT is invalid."))
            }
            if normalizedBIC.isEmpty {
                result.warningMessages.append(String(localized: "BIC/SWIFT is usually useful for international transfers."))
            }

        case .paypal:
            if normalizedEmail.isEmpty, normalizedURL.isEmpty {
                result.blockingMessages.append(String(localized: "PayPal email or link is required."))
            }
            if !normalizedEmail.isEmpty, !Self.isValidEmail(normalizedEmail) {
                result.blockingMessages.append(String(localized: "PayPal email is invalid."))
            }
            if !normalizedURL.isEmpty, !Self.isValidURL(normalizedURL) {
                result.blockingMessages.append(String(localized: "PayPal link is invalid."))
            }

        case .wise:
            if normalizedEmail.isEmpty, normalizedURL.isEmpty, normalizedInstructions.isEmpty {
                result.blockingMessages.append(String(localized: "Wise email, link, or instructions are required."))
            }
            if !normalizedEmail.isEmpty, !Self.isValidEmail(normalizedEmail) {
                result.blockingMessages.append(String(localized: "Wise email is invalid."))
            }
            if !normalizedURL.isEmpty, !Self.isValidURL(normalizedURL) {
                result.blockingMessages.append(String(localized: "Wise link is invalid."))
            }

        case .paymentLink:
            if normalizedURL.isEmpty {
                result.blockingMessages.append(String(localized: "Payment link URL is required."))
            } else if !Self.isValidURL(normalizedURL) {
                result.blockingMessages.append(String(localized: "Payment link URL is invalid."))
            }

        case .other:
            if normalizedInstructions.isEmpty {
                result.blockingMessages.append(String(localized: "Payment instructions are required."))
            }
        }

        return result
    }

    var isValidForInvoiceFinalization: Bool {
        validation.isValid && hasPrintableInstructions
    }

    var sanitized: WorkspacePaymentMethod {
        WorkspacePaymentMethod(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            placement: placement,
            isVisible: isVisible,
            sortOrder: sortOrder,
            accountHolder: accountHolder.trimmingCharacters(in: .whitespacesAndNewlines),
            iban: Self.formattedIBAN(iban),
            bic: bic.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
            instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var isSEPAEligible: Bool {
        type == .sepaBankTransfer && Self.isValidIBAN(Self.normalizedIBAN(iban))
    }

    static func normalizedIBAN(_ value: String) -> String {
        value
            .filter { !$0.isWhitespace }
            .uppercased()
    }

    static func formattedIBAN(_ value: String) -> String {
        normalizedIBAN(value)
            .chunked(every: 4)
            .joined(separator: " ")
    }

    private static func isValidIBAN(_ value: String) -> Bool {
        let normalized = normalizedIBAN(value)
        guard normalized.count >= 15,
              normalized.count <= 34,
              normalized.allSatisfy({ $0.isNumber || $0.isLetter })
        else {
            return false
        }

        let rearranged = normalized.dropFirst(4) + normalized.prefix(4)
        var remainder = 0
        for character in rearranged {
            guard let numericValue = ibanNumericValue(for: character) else {
                return false
            }
            for digit in numericValue {
                guard let wholeNumber = digit.wholeNumberValue else { return false }
                remainder = (remainder * 10 + wholeNumber) % 97
            }
        }
        return remainder == 1
    }

    private static func ibanNumericValue(for character: Character) -> String? {
        if character.isNumber {
            return String(character)
        }
        guard let scalar = character.unicodeScalars.first,
              scalar.properties.isAlphabetic
        else {
            return nil
        }
        let value = Int(scalar.value) - Int(UnicodeScalar("A").value) + 10
        guard value >= 10, value <= 35 else { return nil }
        return String(value)
    }

    private static func isValidBIC(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 8 || normalized.count == 11 else {
            return false
        }

        let bankCode = normalized.prefix(4)
        let countryCode = normalized.dropFirst(4).prefix(2)
        return bankCode.allSatisfy(\.isLetter)
            && countryCode.allSatisfy(\.isLetter)
            && normalized.allSatisfy { $0.isLetter || $0.isNumber }
    }

    private static func isValidEmail(_ value: String) -> Bool {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "@")
        guard parts.count == 2,
              let local = parts.first,
              let domain = parts.last,
              !local.isEmpty,
              domain.contains("."),
              !domain.hasPrefix("."),
              !domain.hasSuffix(".")
        else {
            return false
        }
        return !value.contains(" ")
    }

    private static func isValidURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              host.contains(".")
        else {
            return false
        }
        return true
    }
}

private extension String {
    func chunked(every size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map { offset in
            let start = index(startIndex, offsetBy: offset)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
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
