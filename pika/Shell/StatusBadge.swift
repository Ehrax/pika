import SwiftUI

struct StatusBadge: View {
    var tone: PikaStatusTone
    var title: String

    init(_ tone: PikaStatusTone, title: String) {
        self.tone = tone
        self.title = title
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(PikaTypography.small)
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, PikaSpacing.xs)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.pill))
        .accessibilityLabel("\(tone.accessibilityLabel): \(title)")
    }
}

struct SectionHeader: View {
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(PikaTypography.subheading)
                .foregroundStyle(PikaColor.textPrimary)
            Spacer()
            Text(detail)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textSecondary)
        }
    }
}

extension View {
    func pikaSurface() -> some View {
        background(PikaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: PikaRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: PikaRadius.lg)
                    .stroke(PikaColor.border)
            }
    }
}
