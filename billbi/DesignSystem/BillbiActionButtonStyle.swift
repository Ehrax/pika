import SwiftUI

enum BillbiActionButtonTone {
    case primary
    case neutral
    case destructive
    case success
    case warning
}

enum BillbiActionButtonSize {
    case regular
    case large
}

struct BillbiActionButtonStyle: ButtonStyle {
    let tone: BillbiActionButtonTone
    let size: BillbiActionButtonSize
    @Environment(\.isEnabled) private var isEnabled

    init(tone: BillbiActionButtonTone = .primary, size: BillbiActionButtonSize = .regular) {
        self.tone = tone
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.38))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous)
                    .stroke(border.opacity(isEnabled ? 1 : 0.5), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private var font: Font {
        switch size {
        case .regular:
            BillbiTypography.small.weight(.medium)
        case .large:
            BillbiTypography.heading.weight(.semibold)
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular:
            12
        case .large:
            18
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular:
            7
        case .large:
            10
        }
    }

    private var foreground: Color {
        switch tone {
        case .primary:
            BillbiColor.brand
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
            BillbiColor.brandMuted
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
            BillbiColor.brandBorder
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
    static func billbiAction(
        _ tone: BillbiActionButtonTone = .primary,
        size: BillbiActionButtonSize = .regular
    ) -> BillbiActionButtonStyle {
        BillbiActionButtonStyle(tone: tone, size: size)
    }
}
