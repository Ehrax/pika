import SwiftUI

enum PikaStatusTone: Hashable {
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
            PikaColor.success
        case .warning:
            PikaColor.warning
        case .danger:
            PikaColor.danger
        case .neutral:
            PikaColor.textSecondary
        }
    }

    var mutedColor: Color {
        switch self {
        case .success:
            PikaColor.successMuted
        case .warning:
            PikaColor.warningMuted
        case .danger:
            PikaColor.dangerMuted
        case .neutral:
            PikaColor.surfaceAlt
        }
    }
}
