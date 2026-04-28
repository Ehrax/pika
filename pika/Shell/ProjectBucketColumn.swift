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
        PikaSecondarySidebarColumn(
            title: project.name,
            subtitle: project.clientName,
            sectionTitle: "Buckets"
        ) {
            Button {
                onCreateBucket()
            } label: {
                Label("Create a bucket", systemImage: "plus")
            }
            .buttonStyle(PikaColumnHeaderIconButtonStyle())
            .help("Create a bucket")
        } controls: {
            EmptyView()
        } content: {
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !project.isArchived, row.status == .archived {
                            Button(role: .destructive) {
                                onRemoveBucket(row.id)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        } else if !project.isArchived, !row.status.isInvoiceLocked {
                            Button {
                                onArchiveBucket(row.id)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(PikaColor.warning)
                        }
                    }
                    .contextMenu {
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
                            .tint(PikaColor.warning)
                        }
                    }
                }
            }
        }
    }
}

struct PikaSecondarySidebarColumn<Actions: View, Controls: View, Content: View>: View {
    let title: String
    let subtitle: String
    let sectionTitle: String
    let actions: Actions
    let controls: Controls
    let content: Content
    @State private var columnMinX = CGFloat.greatestFiniteMagnitude

    init(
        title: String,
        subtitle: String,
        sectionTitle: String,
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            controls
                .padding(.horizontal, PikaSpacing.md)
                .padding(.bottom, PikaSpacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: PikaSpacing.sm) {
                    Text(sectionTitle)
                        .font(PikaTypography.subheading)
                        .foregroundStyle(PikaColor.textPrimary)
                        .padding(.horizontal, PikaSpacing.md)
                        .padding(.top, PikaSpacing.md)

                    content
                        .padding(.horizontal, PikaSpacing.sm)
                        .padding(.bottom, PikaSpacing.md)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(PikaColor.surface.ignoresSafeArea(.container, edges: .top))
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: PikaSecondarySidebarColumnMinXPreferenceKey.self,
                        value: proxy.frame(in: .global).minX
                    )
            }
        }
        .onPreferenceChange(PikaSecondarySidebarColumnMinXPreferenceKey.self) { newValue in
            if abs(columnMinX - newValue) > 0.5 {
                columnMinX = newValue
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: PikaSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PikaTypography.heading)
                    .foregroundStyle(PikaColor.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(PikaTypography.body.weight(.medium))
                    .foregroundStyle(PikaColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: PikaSpacing.sm)

            actions
        }
        .padding(.leading, PikaSpacing.md + PikaSecondarySidebarLayout.leadingChromeClearance(forColumnMinX: columnMinX))
        .padding(.trailing, PikaSpacing.md)
        .padding(.top, PikaSecondarySidebarLayout.headerTopPadding)
        .padding(.bottom, PikaSpacing.md)
    }
}

enum PikaSecondarySidebarLayout {
    #if os(macOS)
    static let headerTopPadding: CGFloat = PikaSpacing.md
    static let leadingColumnDetectionThreshold: CGFloat = 96
    static let leadingWindowChromeClearance: CGFloat = 116
    #else
    static let headerTopPadding: CGFloat = PikaSpacing.md
    static let leadingColumnDetectionThreshold: CGFloat = 0
    static let leadingWindowChromeClearance: CGFloat = 0
    #endif

    static func leadingChromeClearance(forColumnMinX columnMinX: CGFloat) -> CGFloat {
        columnMinX < leadingColumnDetectionThreshold ? leadingWindowChromeClearance : 0
    }
}

private struct PikaSecondarySidebarColumnMinXPreferenceKey: PreferenceKey {
    static let defaultValue = CGFloat.greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PikaColumnHeaderIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(PikaColor.textPrimary.opacity(isEnabled ? 1 : 0.38))
            .frame(width: 28, height: 28)
            .glassEffect(
                .regular
                    .tint(PikaColor.textPrimary.opacity(0.06))
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
                StatusBadge(row.statusTone, title: statusTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PikaSpacing.sm)
        .padding(.vertical, 10)
        .pikaSecondarySidebarRow(isSelected: isSelected)
    }
}

private struct PikaSecondarySidebarRowModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(isSelected ? PikaColor.surfaceAlt2 : Color.clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(PikaColor.accent)
                        .frame(width: 3)
                        .padding(.vertical, 9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
    }
}

extension View {
    func pikaSecondarySidebarRow(isSelected: Bool) -> some View {
        modifier(PikaSecondarySidebarRowModifier(isSelected: isSelected))
    }
}
