import SwiftUI

enum PikaActionButtonTone {
    case primary
    case neutral
    case destructive
    case success
    case warning
}

struct PikaActionButtonStyle: ButtonStyle {
    let tone: PikaActionButtonTone
    @Environment(\.isEnabled) private var isEnabled

    init(tone: PikaActionButtonTone = .primary) {
        self.tone = tone
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PikaTypography.small.weight(.medium))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.38))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(background.opacity(isEnabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: PikaRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PikaRadius.sm, style: .continuous)
                    .stroke(border.opacity(isEnabled ? 1 : 0.5), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: PikaRadius.sm, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private var foreground: Color {
        switch tone {
        case .primary:
            PikaColor.actionAccent
        case .neutral:
            PikaColor.textPrimary
        case .destructive:
            PikaColor.danger
        case .success:
            PikaColor.success
        case .warning:
            PikaColor.warning
        }
    }

    private var background: Color {
        switch tone {
        case .primary:
            PikaColor.actionAccentMuted
        case .neutral:
            PikaColor.textPrimary.opacity(0.07)
        case .destructive:
            PikaColor.dangerMuted
        case .success:
            PikaColor.successMuted
        case .warning:
            PikaColor.warningMuted
        }
    }

    private var border: Color {
        switch tone {
        case .primary:
            PikaColor.actionAccent.opacity(0.34)
        case .neutral:
            PikaColor.textPrimary.opacity(0.16)
        case .destructive:
            PikaColor.danger.opacity(0.34)
        case .success:
            PikaColor.success.opacity(0.34)
        case .warning:
            PikaColor.warning.opacity(0.34)
        }
    }
}

extension ButtonStyle where Self == PikaActionButtonStyle {
    static func pikaAction(_ tone: PikaActionButtonTone = .primary) -> PikaActionButtonStyle {
        PikaActionButtonStyle(tone: tone)
    }
}
