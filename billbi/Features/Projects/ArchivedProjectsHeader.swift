import SwiftUI

struct ArchivedProjectsHeader: View {
    let count: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Text("\(count) archived projects")
                .font(BillbiTypography.subheading)
                .foregroundStyle(BillbiColor.textPrimary)

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BillbiColor.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
        }
        .frame(minHeight: 28, alignment: .leading)
        .contentShape(Rectangle())
    }
}
