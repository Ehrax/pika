import Foundation

extension Calendar {
    static let pikaGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static let pikaStoreGregorian = pikaGregorian
}
