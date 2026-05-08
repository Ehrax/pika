import SwiftUI

enum BillbiStatusTone: Hashable {
    case success
    case info
    case warning
    case danger
    case neutral

    var accessibilityLabel: String {
        switch self {
        case .success:
            String(localized: "Success")
        case .info:
            String(localized: "Info")
        case .warning:
            String(localized: "Warning")
        case .danger:
            String(localized: "Danger")
        case .neutral:
            String(localized: "Neutral")
        }
    }

    var color: Color {
        switch self {
        case .success:
            BillbiColor.success
        case .info:
            BillbiColor.info
        case .warning:
            BillbiColor.warning
        case .danger:
            BillbiColor.danger
        case .neutral:
            BillbiColor.textSecondary
        }
    }

    var mutedColor: Color {
        switch self {
        case .success:
            BillbiColor.successMuted
        case .info:
            BillbiColor.infoMuted
        case .warning:
            BillbiColor.warningMuted
        case .danger:
            BillbiColor.dangerMuted
        case .neutral:
            BillbiColor.surfaceAlt
        }
    }
}
