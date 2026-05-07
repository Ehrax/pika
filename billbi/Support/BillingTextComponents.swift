import Foundation

struct BillingAddressComponents: Equatable {
    var street: String = ""
    var postalCode: String = ""
    var city: String = ""
    var country: String = ""

    init() {}

    init(rawAddress: String) {
        let normalized = rawAddress
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            return
        }

        let lines = normalized
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count >= 2 {
            street = lines[0]
            splitPostalAndCity(from: lines[1], fallbackStreet: nil)
            if lines.count >= 3 {
                country = lines[2]
            }
            return
        }

        if normalized.contains(",") {
            let parts = normalized
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if let first = parts.first {
                street = first
            }
            if parts.count > 1 {
                splitPostalAndCity(from: parts[1], fallbackStreet: nil)
            }
            if parts.count > 2 {
                country = parts[2]
            }
            return
        }

        splitPostalAndCity(from: normalized, fallbackStreet: normalized)
    }

    var singleString: String {
        let secondLine = [postalCode, city]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let lines = [
            street.trimmingCharacters(in: .whitespacesAndNewlines),
            secondLine,
            country.trimmingCharacters(in: .whitespacesAndNewlines),
        ].filter { !$0.isEmpty }

        return lines.joined(separator: "\n")
    }

    private mutating func splitPostalAndCity(from input: String, fallbackStreet: String?) {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            if let fallbackStreet {
                street = fallbackStreet
            }
            return
        }

        let pattern = #"\b\d{4,5}\b"#
        guard let range = raw.range(of: pattern, options: .regularExpression) else {
            if let fallbackStreet {
                street = fallbackStreet
            } else {
                city = raw
            }
            return
        }

        let prefix = raw[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let code = raw[range].trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = raw[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)

        postalCode = code
        city = suffix

        if let fallbackStreet, street.isEmpty {
            street = prefix.isEmpty ? fallbackStreet : prefix
        } else if street.isEmpty {
            street = prefix
        }
    }
}

struct PaymentDetailsComponents: Equatable {
    var accountName: String = ""
    var iban: String = ""
    var bic: String = ""

    init() {}

    init(rawValue: String) {
        let lines = rawValue
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in lines {
            if let value = Self.lineValue(after: "Account name", in: line) {
                accountName = value
            } else if let value = Self.lineValue(after: "Name", in: line), accountName.isEmpty {
                accountName = value
            } else if let value = Self.lineValue(after: "IBAN", in: line) {
                iban = Self.formattedIBAN(value)
            } else if let value = Self.lineValue(after: "BIC", in: line) {
                bic = value.uppercased()
            }
        }

        let words = rawValue
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(separator: " ")
            .map(String.init)

        if iban.isEmpty {
            iban = Self.value(after: "IBAN", in: words, stoppingAt: ["BIC"]).map(Self.formattedIBAN) ?? ""
        }
        if bic.isEmpty {
            bic = Self.value(after: "BIC", in: words)?.uppercased() ?? ""
        }
    }

    var rawValue: String {
        var lines: [String] = []
        let normalizedAccountName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedAccountName.isEmpty {
            lines.append("Account name \(normalizedAccountName)")
        }

        let normalizedIBAN = Self.formattedIBAN(iban)
        if !normalizedIBAN.isEmpty {
            lines.append("IBAN \(normalizedIBAN)")
        }

        let normalizedBIC = bic.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !normalizedBIC.isEmpty {
            lines.append("BIC \(normalizedBIC)")
        }

        return lines.joined(separator: "\n")
    }

    nonisolated private static func value(
        after label: String,
        in words: [String],
        stoppingAt stopLabels: Set<String> = ["IBAN", "BIC", "Account", "Name"]
    ) -> String? {
        guard let labelIndex = words.firstIndex(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) else {
            return nil
        }

        let valueWords = words[(labelIndex + 1)...]
            .prefix { word in
                !stopLabels.contains { stopLabel in
                    word.caseInsensitiveCompare(stopLabel) == .orderedSame
                }
            }
        let value = valueWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    nonisolated private static func lineValue(after label: String, in line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmedLine.range(of: label, options: [.caseInsensitive, .anchored]) else { return nil }

        let value = trimmedLine
            .dropFirst(trimmedLine.distance(from: trimmedLine.startIndex, to: range.upperBound))
            .trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespacesAndNewlines))
        return value.isEmpty ? nil : value
    }

    nonisolated private static func formattedIBAN(_ value: String) -> String {
        let cleanValue = value.filter { !$0.isWhitespace }.uppercased()
        return cleanValue.enumerated().reduce(into: "") { result, pair in
            if pair.offset > 0, pair.offset.isMultiple(of: 4) {
                result.append(" ")
            }
            result.append(pair.element)
        }
    }
}
