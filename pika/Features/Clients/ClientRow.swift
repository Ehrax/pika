import SwiftUI

struct ClientRow: View {
    let client: WorkspaceClient
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            Image(systemName: "building.2")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(PikaTypography.body.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(PikaColor.textPrimary)
                    .lineLimit(1)
                Text(client.email)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if client.isArchived {
                StatusBadge(.neutral, title: "Archived")
            } else {
                Text("\(client.defaultTermsDays)d")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PikaColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, 10)
        .pikaSecondarySidebarRow(isSelected: isSelected)
    }
}
