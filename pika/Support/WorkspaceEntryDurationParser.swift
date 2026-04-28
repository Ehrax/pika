import Foundation

enum WorkspaceEntryDurationParser {
    static func minutes(from input: String) -> Int? {
        let normalized = normalized(input)

        guard !normalized.isEmpty else { return nil }

        if normalized.hasSuffix("m"),
           let minutes = Int(normalized.dropLast().trimmingCharacters(in: .whitespaces)) {
            return minutes > 0 ? minutes : nil
        }

        if normalized.hasSuffix("h"),
           let hours = Double(normalized.dropLast().trimmingCharacters(in: .whitespaces)) {
            let minutes = Int((hours * 60).rounded())
            return minutes > 0 ? minutes : nil
        }

        let parts = normalized
            .split(separator: "-", maxSplits: 1)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let start = minutesSinceStartOfDay(parts[0]),
              let end = minutesSinceStartOfDay(parts[1]),
              end > start
        else {
            return nil
        }

        return end - start
    }

    static func timeRangeLabels(from input: String) -> (start: String, end: String)? {
        let parts = normalized(input)
            .split(separator: "-", maxSplits: 1)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let start = minutesSinceStartOfDay(parts[0]),
              let end = minutesSinceStartOfDay(parts[1]),
              end > start
        else {
            return nil
        }

        return (timeLabel(minutes: start), timeLabel(minutes: end))
    }

    static func displayLabel(from input: String) -> String {
        normalized(input)
    }

    private static func normalized(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .lowercased()
    }

    private static func minutesSinceStartOfDay(_ input: String) -> Int? {
        let parts = input.split(separator: ":", maxSplits: 1)
        guard let hours = Int(parts[0]), hours >= 0, hours <= 23 else {
            return nil
        }

        let minutes: Int
        if parts.count == 2 {
            guard let parsedMinutes = Int(parts[1]), parsedMinutes >= 0, parsedMinutes <= 59 else {
                return nil
            }
            minutes = parsedMinutes
        } else {
            minutes = 0
        }

        return hours * 60 + minutes
    }

    private static func timeLabel(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return String(format: "%02d:%02d", locale: Locale(identifier: "en_US_POSIX"), hours, remainder)
    }
}
