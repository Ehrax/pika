import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            SectionHeader(title: title)

            VStack(spacing: 0) {
                content
            }
            .billbiSurface()
        }
    }
}

struct SettingsEditableFieldRow<Content: View>: View {
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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, BillbiSpacing.md)
        .padding(.vertical, BillbiSpacing.sm)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, BillbiSpacing.md)
    }
}
