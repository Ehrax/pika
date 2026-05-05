import SwiftUI

struct ClientRow: View {
    let client: WorkspaceClient
    let isSelected: Bool

    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: "building.2")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(BillbiTypography.body.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(client.email)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if client.isArchived {
                StatusBadge(.neutral, title: "Archived")
            } else {
                Text("\(client.defaultTermsDays)d")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: isSelected)
    }
}
