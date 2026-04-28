import SwiftUI

struct PikaInputSheetSection<Content: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(PikaTypography.subheading)
                    .foregroundStyle(PikaColor.textPrimary)

                Spacer()

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(PikaTypography.small)
                        .foregroundStyle(PikaColor.textSecondary)
                }
            }

            VStack(spacing: 0) {
                content
            }
            .pikaSurface()
        }
    }
}

struct PikaInputSheetFieldRow<Content: View>: View {
    let label: String
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: PikaSpacing.lg) {
            Text(label)
                .font(PikaTypography.small)
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 180, alignment: .leading)

            content
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, PikaSpacing.sm)
    }
}

struct PikaInputSheetDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, PikaSpacing.md)
    }
}
