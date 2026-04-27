import SwiftUI

struct ProjectBucketColumn: View {
    let project: WorkspaceProject
    let projection: WorkspaceBucketDetailProjection
    let selectedBucketID: WorkspaceBucket.ID
    let onSelect: (WorkspaceBucket.ID) -> Void
    let onCreateBucket: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(projection.bucketRows) { row in
                        Button {
                            onSelect(row.id)
                        } label: {
                            ProjectBucketRow(row: row, isSelected: row.id == selectedBucketID)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PikaSpacing.sm)
                .padding(.bottom, PikaSpacing.md)
            }
        }
        .frame(minWidth: 220, idealWidth: 280, maxWidth: 520)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(PikaColor.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PikaColor.border)
                .frame(width: 1)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Buckets")
                    .font(PikaTypography.micro)
                    .foregroundStyle(PikaColor.textMuted)
                    .textCase(.uppercase)
                Text(project.clientName)
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onCreateBucket()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Create a bucket")
        }
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, PikaSpacing.md)
    }
}

private struct ProjectBucketRow: View {
    let row: WorkspaceBucketRowProjection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PikaSpacing.sm) {
            Image(systemName: row.status == .finalized ? "doc.text.fill" : "diamond")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PikaColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(PikaTypography.body.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(PikaColor.textPrimary)
                    .lineLimit(1)
                Text(row.meta)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PikaColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: PikaSpacing.sm)

            if let statusTitle = row.statusTitle {
                StatusBadge(row.status.pikaTone, title: statusTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, 10)
        .background(isSelected ? PikaColor.surfaceAlt : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? PikaColor.accent : Color.clear)
                .frame(width: 2)
        }
    }
}

extension BucketStatus {
    var pikaTone: PikaStatusTone {
        switch self {
        case .open:
            .neutral
        case .ready:
            .success
        case .finalized:
            .warning
        case .archived:
            .neutral
        }
    }
}
