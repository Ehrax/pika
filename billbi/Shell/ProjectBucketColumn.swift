import SwiftUI

struct ProjectBucketColumn: View {
    let project: WorkspaceProject
    let projection: WorkspaceBucketDetailProjection
    let selectedBucketID: WorkspaceBucket.ID
    let onSelect: (WorkspaceBucket.ID) -> Void
    let onCreateBucket: () -> Void
    let onArchiveBucket: (WorkspaceBucket.ID) -> Void
    let onRemoveBucket: (WorkspaceBucket.ID) -> Void

    var body: some View {
        BillbiSecondarySidebarColumn(
            title: project.name,
            subtitle: project.clientName,
            sectionTitle: "Buckets",
            wrapsContentInScrollView: false
        ) {
            Button {
                onCreateBucket()
            } label: {
                Label("Create a bucket", systemImage: "plus")
            }
            .buttonStyle(BillbiColumnHeaderIconButtonStyle(foreground: BillbiColor.brand))
            .help("Create a bucket")
        } controls: {
            EmptyView()
        } content: {
            VStack(spacing: 0) {
                Divider()
                bucketList
                    .padding(.top, BillbiSpacing.md)
            }
        }
    }

    private var bucketList: some View {
        List {
            ForEach(projection.bucketRows) { row in
                Button {
                    onSelect(row.id)
                } label: {
                    ProjectBucketRow(row: row, isSelected: row.id == selectedBucketID)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 1, leading: BillbiSpacing.sm, bottom: 1, trailing: BillbiSpacing.sm))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    bucketSwipeActions(for: row)
                }
                .contextMenu {
                    bucketMenuActions(for: row)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BillbiColor.surface)
    }

    @ViewBuilder
    private func bucketSwipeActions(for row: WorkspaceBucketRowProjection) -> some View {
        if !project.isArchived, row.status == .archived {
            Button(role: .destructive) {
                onRemoveBucket(row.id)
            } label: {
                Label("Remove", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .tint(BillbiColor.danger)
        } else if !project.isArchived, !row.status.isInvoiceLocked {
            Button {
                onArchiveBucket(row.id)
            } label: {
                Label("Archive", systemImage: "archivebox")
                    .labelStyle(.iconOnly)
            }
            .tint(BillbiColor.warning)
        }
    }

    @ViewBuilder
    private func bucketMenuActions(for row: WorkspaceBucketRowProjection) -> some View {
        if !project.isArchived, row.status == .archived {
            Button(role: .destructive) {
                onRemoveBucket(row.id)
            } label: {
                Label("Remove Bucket", systemImage: "trash")
            }
        } else if !project.isArchived, !row.status.isInvoiceLocked {
            Button {
                onArchiveBucket(row.id)
            } label: {
                Label("Archive Bucket", systemImage: "archivebox")
            }
        }
    }
}

struct BillbiSecondarySidebarColumn<Actions: View, Controls: View, Content: View>: View {
    let title: String
    let subtitle: String
    let sectionTitle: String
    let actions: Actions
    let controls: Controls
    let content: Content
    let wrapsContentInScrollView: Bool
    @State private var columnMinX = CGFloat.greatestFiniteMagnitude

    init(
        title: String,
        subtitle: String,
        sectionTitle: String,
        wrapsContentInScrollView: Bool = true,
        @ViewBuilder actions: () -> Actions,
        @ViewBuilder controls: () -> Controls,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.sectionTitle = sectionTitle
        self.actions = actions()
        self.controls = controls()
        self.content = content()
        self.wrapsContentInScrollView = wrapsContentInScrollView
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            controls
                .padding(.horizontal, BillbiSpacing.md)
                .padding(.bottom, BillbiSpacing.sm)

            if wrapsContentInScrollView {
                ScrollView {
                    VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                        Text(sectionTitle)
                            .font(BillbiTypography.subheading)
                            .foregroundStyle(BillbiColor.textPrimary)
                            .padding(.horizontal, BillbiSpacing.md)
                            .padding(.top, BillbiSpacing.md)

                        content
                            .padding(.horizontal, BillbiSpacing.sm)
                            .padding(.bottom, BillbiSpacing.md)
                    }
                }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(BillbiColor.surface.ignoresSafeArea(.container, edges: .top))
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: BillbiSecondarySidebarColumnMinXPreferenceKey.self,
                        value: proxy.frame(in: .global).minX
                    )
            }
        }
        .onPreferenceChange(BillbiSecondarySidebarColumnMinXPreferenceKey.self) { newValue in
            if abs(columnMinX - newValue) > 0.5 {
                columnMinX = newValue
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: BillbiSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BillbiTypography.heading)
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(BillbiTypography.body.weight(.medium))
                    .foregroundStyle(BillbiColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)

            actions
        }
        .padding(.leading, BillbiSpacing.md + BillbiSecondarySidebarLayout.leadingChromeClearance(forColumnMinX: columnMinX))
        .padding(.trailing, BillbiSpacing.md)
        .padding(.top, BillbiSecondarySidebarLayout.headerTopPadding)
        .padding(.bottom, BillbiSpacing.md)
    }
}

enum BillbiSecondarySidebarLayout {
    #if os(macOS)
    static let headerTopPadding: CGFloat = BillbiSpacing.md
    static let leadingColumnDetectionThreshold: CGFloat = 96
    static let leadingWindowChromeClearance: CGFloat = 116
    #else
    static let headerTopPadding: CGFloat = BillbiSpacing.md
    static let leadingColumnDetectionThreshold: CGFloat = 0
    static let leadingWindowChromeClearance: CGFloat = 0
    #endif

    static func leadingChromeClearance(forColumnMinX columnMinX: CGFloat) -> CGFloat {
        columnMinX < leadingColumnDetectionThreshold ? leadingWindowChromeClearance : 0
    }
}

private struct BillbiSecondarySidebarColumnMinXPreferenceKey: PreferenceKey {
    static let defaultValue = CGFloat.greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct BillbiColumnHeaderIconButtonStyle: ButtonStyle {
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    init(foreground: Color = BillbiColor.textPrimary) {
        self.foreground = foreground
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.38))
            .frame(width: 28, height: 28)
            .glassEffect(
                .regular
                    .tint(foreground.opacity(0.06))
                    .interactive(),
                in: Circle()
            )
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct ProjectBucketRow: View {
    let row: WorkspaceBucketRowProjection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: BillbiSpacing.sm) {
            Image(systemName: row.status == .finalized ? "doc.text.fill" : "diamond")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(BillbiColor.textMuted)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(BillbiTypography.body.weight(isSelected ? .medium : .regular))
                    .foregroundStyle(BillbiColor.textPrimary)
                    .lineLimit(1)
                Text(row.meta)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BillbiColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: BillbiSpacing.sm)

            if let statusTitle = row.statusTitle {
                StatusBadge(row.statusTone, title: statusTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, 10)
        .billbiSecondarySidebarRow(isSelected: isSelected)
    }
}
