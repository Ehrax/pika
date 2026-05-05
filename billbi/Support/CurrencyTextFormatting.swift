import Foundation

enum CurrencyTextFormatting {
    static func normalizedInput(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalized = ""
        var previousCharacter: Character?

        for character in trimmedValue {
            if character.isLetter, previousCharacter?.isNumber == true {
                normalized.append(" ")
            }

            normalized.append(character)
            previousCharacter = character
        }

        return normalized.uppercased()
    }
}
