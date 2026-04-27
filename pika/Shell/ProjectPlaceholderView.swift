import SwiftUI

struct ProjectPlaceholderView: View {
    let project: WorkspaceProject?
    @State private var selectedBucketID: WorkspaceBucket.ID?

    private let formatter = MoneyFormatting.euros(locale: Locale(identifier: "en_US_POSIX"))

    var body: some View {
        Group {
            if
                let project,
                let projection = project.detailProjection(
                    selectedBucketID: selectedBucketID,
                    formatter: formatter
                )
            {
                let activeBucketID = project.normalizedBucketID(selectedBucketID) ?? projection.selectedBucket.id

                HStack(spacing: 0) {
                    BucketColumn(
                        project: project,
                        projection: projection,
                        selectedBucketID: activeBucketID,
                        onSelect: { bucketID in
                            selectedBucketID = bucketID
                            AppTelemetry.projectBucketSelected(projectName: project.name)
                        }
                    )

                    BucketDetailPane(projection: projection)
                }
                .background(PikaColor.background)
                .onAppear {
                    selectedBucketID = activeBucketID
                    AppTelemetry.projectDetailLoaded(projectName: project.name, bucketCount: projection.bucketRows.count)
                }
                .onChange(of: project.id) { _, _ in
                    selectedBucketID = nil
                }
            } else {
                ContentUnavailableView("Project not found", systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PikaColor.background)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(project?.name ?? "Project")
        .toolbar {
            Button {
            } label: {
                Label("New Bucket", systemImage: "plus")
            }
            .disabled(true)
            .help("Bucket creation lands in a later task")

            Button {
            } label: {
                Label("Mark Ready", systemImage: "checkmark.circle")
            }
            .disabled(true)
            .help("Bucket status actions land in the bucket workflow task")
        }
    }

}

private struct BucketColumn: View {
    let project: WorkspaceProject
    let projection: WorkspaceBucketDetailProjection
    let selectedBucketID: WorkspaceBucket.ID
    let onSelect: (WorkspaceBucket.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(true)
                .help("Bucket creation lands in a later task")
            }
            .padding(.horizontal, PikaSpacing.md)
            .padding(.vertical, PikaSpacing.md)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(projection.bucketRows) { row in
                        Button {
                            onSelect(row.id)
                        } label: {
                            BucketRow(row: row, isSelected: row.id == selectedBucketID)
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
        .frame(width: 260)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(PikaColor.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(PikaColor.border)
                .frame(width: 1)
        }
    }
}

private struct BucketRow: View {
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

private extension BucketStatus {
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

private struct BucketDetailPane: View {
    let projection: WorkspaceBucketDetailProjection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PikaSpacing.lg) {
                BucketHeader(projection: projection)

                HStack(spacing: PikaSpacing.md) {
                    SummaryTile(title: "Billable", value: projection.billableSummary)
                    SummaryTile(title: "Non-billable", value: projection.nonBillableSummary)
                    SummaryTile(title: "Fixed costs", value: projection.fixedCostLabel)
                }

                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    SectionHeader(title: "Entries and costs", detail: "\(projection.lineItems.count) rows")
                    BucketEntriesTable(lineItems: projection.lineItems)
                }
            }
            .padding(.horizontal, PikaSpacing.xl)
            .padding(.vertical, PikaSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PikaColor.background)
    }
}

private struct BucketHeader: View {
    let projection: WorkspaceBucketDetailProjection

    var body: some View {
        HStack(alignment: .top, spacing: PikaSpacing.lg) {
            VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                Text(projection.title)
                    .font(PikaTypography.display)
                    .foregroundStyle(PikaColor.textPrimary)

                HStack(spacing: PikaSpacing.sm) {
                    Text(projection.projectName)
                    Text("·")
                    Text(projection.clientName)
                    Text("·")
                    Text(projection.currencyCode)
                }
                .font(PikaTypography.body)
                .foregroundStyle(PikaColor.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(projection.totalLabel)
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(PikaColor.textPrimary)
                Text("\(projection.billableSummary) · \(projection.nonBillableSummary)")
                    .font(PikaTypography.small)
                    .foregroundStyle(PikaColor.textMuted)
            }
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: PikaSpacing.xs) {
            Text(title)
                .font(PikaTypography.micro)
                .foregroundStyle(PikaColor.textMuted)
                .textCase(.uppercase)
            Text(value)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(PikaColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PikaSpacing.md)
        .pikaSurface()
    }
}

private struct BucketEntriesTable: View {
    let lineItems: [WorkspaceBucketLineItemProjection]

    var body: some View {
        VStack(spacing: 0) {
            TableHeader()

            ForEach(lineItems) { item in
                HStack(spacing: PikaSpacing.md) {
                    Text(item.description)
                        .font(PikaTypography.body)
                        .foregroundStyle(item.isBillable ? PikaColor.textPrimary : PikaColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.quantity)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(PikaColor.textSecondary)
                        .frame(width: 120, alignment: .trailing)
                    Text(item.amountLabel)
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(item.isBillable ? PikaColor.textPrimary : PikaColor.textMuted)
                        .frame(width: 120, alignment: .trailing)
                }
                .padding(.horizontal, PikaSpacing.md)
                .padding(.vertical, 12)

                if item.id != lineItems.last?.id {
                    Divider()
                        .overlay(PikaColor.border)
                }
            }
        }
        .pikaSurface()
    }
}

private struct TableHeader: View {
    var body: some View {
        HStack(spacing: PikaSpacing.md) {
            Text("Description")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Qty")
                .frame(width: 120, alignment: .trailing)
            Text("Amount")
                .frame(width: 120, alignment: .trailing)
        }
        .font(PikaTypography.micro)
        .foregroundStyle(PikaColor.textMuted)
        .textCase(.uppercase)
        .padding(.horizontal, PikaSpacing.md)
        .padding(.vertical, 10)
        .background(PikaColor.surfaceAlt)
    }
}
