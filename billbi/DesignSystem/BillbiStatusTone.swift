import SwiftUI

enum BillbiStatusTone: Hashable {
    case success
    case warning
    case danger
    case neutral

    var accessibilityLabel: String {
        switch self {
        case .success:
            "Success"
        case .warning:
            "Warning"
        case .danger:
            "Danger"
        case .neutral:
            "Neutral"
        }
    }

    var color: Color {
        switch self {
        case .success:
            BillbiColor.success
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
        case .warning:
            BillbiColor.warningMuted
        case .danger:
            BillbiColor.dangerMuted
        case .neutral:
            BillbiColor.surfaceAlt
        }
    }
}
