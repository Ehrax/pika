import SwiftUI

enum BillbiActionButtonTone {
    case primary
    case neutral
    case destructive
    case success
    case warning
}

struct BillbiActionButtonStyle: ButtonStyle {
    let tone: BillbiActionButtonTone
    @Environment(\.isEnabled) private var isEnabled

    init(tone: BillbiActionButtonTone = .primary) {
        self.tone = tone
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BillbiTypography.small.weight(.medium))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.38))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(background.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous)
                    .stroke(border.opacity(isEnabled ? 1 : 0.5), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private var foreground: Color {
        switch tone {
        case .primary:
            BillbiColor.actionAccent
        case .neutral:
            BillbiColor.textPrimary
        case .destructive:
            BillbiColor.danger
        case .success:
            BillbiColor.success
        case .warning:
            BillbiColor.warning
        }
    }

    private var background: Color {
        switch tone {
        case .primary:
            BillbiColor.actionAccentMuted
        case .neutral:
            BillbiColor.textPrimary.opacity(0.07)
        case .destructive:
            BillbiColor.dangerMuted
        case .success:
            BillbiColor.successMuted
        case .warning:
            BillbiColor.warningMuted
        }
    }

    private var border: Color {
        switch tone {
        case .primary:
            BillbiColor.actionAccentBorder
        case .neutral:
            BillbiColor.textPrimary.opacity(0.16)
        case .destructive:
            BillbiColor.danger.opacity(0.34)
        case .success:
            BillbiColor.success.opacity(0.34)
        case .warning:
            BillbiColor.warning.opacity(0.34)
        }
    }
}

extension ButtonStyle where Self == BillbiActionButtonStyle {
    static func billbiAction(_ tone: BillbiActionButtonTone = .primary) -> BillbiActionButtonStyle {
        BillbiActionButtonStyle(tone: tone)
    }
}
