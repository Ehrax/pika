import SwiftUI

struct BillbiInputSheetSection<Content: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(BillbiTypography.subheading)
                    .foregroundStyle(BillbiColor.textPrimary)

                Spacer()

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(BillbiTypography.small)
                        .foregroundStyle(BillbiColor.textSecondary)
                }
            }

            VStack(spacing: 0) {
                content
            }
            .billbiSurface()
        }
    }
}

struct BillbiInputSheetFieldRow<Content: View>: View {
    let label: String
    var alignment: VerticalAlignment = .firstTextBaseline
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: alignment, spacing: BillbiSpacing.lg) {
            Text(label)
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 180, alignment: .leading)

            content
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, BillbiSpacing.sm)
    }
}

struct BillbiInputSheetDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, BillbiSpacing.md)
    }
}
