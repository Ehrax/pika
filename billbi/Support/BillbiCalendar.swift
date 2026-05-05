import Foundation

extension Calendar {
    static let billbiGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static let billbiStoreGregorian = billbiGregorian
}
