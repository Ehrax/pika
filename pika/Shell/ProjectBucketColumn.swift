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
            .buttonStyle(PikaColumnHeaderIconButtonStyle(foreground: PikaColor.actionAccent))
            .help("Create a bucket")
        } controls: {
            EmptyView()
        } content: {
            LazyVStack(spacing: 2) {
                ForEach(projection.bucketRows) { row in
                    ProjectBucketInteractiveRow(
                        row: row,
                        isSelected: row.id == selectedBucketID,
                        canAct: !project.isArchived,
                        onSelect: { onSelect(row.id) },
                        onArchive: { onArchiveBucket(row.id) },
                        onRemove: { onRemoveBucket(row.id) }
                    )
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
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    init(foreground: Color = PikaColor.textPrimary) {
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

private struct ProjectBucketInteractiveRow: View {
    let row: WorkspaceBucketRowProjection
    let isSelected: Bool
    let canAct: Bool
    let onSelect: () -> Void
    let onArchive: () -> Void
    let onRemove: () -> Void

    @State private var isRevealed = false
    @GestureState private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 96

    var body: some View {
        ZStack(alignment: .trailing) {
            if let action {
                Button(role: action.role) {
                    perform(action)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 10)
                        .background(action.background)
                }
                .buttonStyle(.plain)
            }

            Button {
                if isRevealed {
                    setRevealed(false)
                } else {
                    onSelect()
                }
            } label: {
                ProjectBucketRow(row: row, isSelected: isSelected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: currentOffset)
            .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: PikaRadius.md))
        .contextMenu {
            if let action {
                Button(role: action.role) {
                    perform(action)
                } label: {
                    Label(action.menuTitle, systemImage: action.systemImage)
                }
            }
        }
    }

    private var currentOffset: CGFloat {
        let baseOffset = isRevealed ? -actionWidth : 0
        return min(0, max(-actionWidth, baseOffset + dragOffset))
    }

    private var action: ProjectBucketRowAction? {
        guard canAct else { return nil }

        if row.status == .archived {
            return .remove
        }

        if !row.status.isInvoiceLocked {
            return .archive
        }

        return nil
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                guard action != nil, abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard action != nil, abs(value.translation.width) > abs(value.translation.height) else { return }

                let baseOffset = isRevealed ? -actionWidth : 0
                setRevealed(baseOffset + value.translation.width < -(actionWidth / 2))
            }
    }

    private func perform(_ action: ProjectBucketRowAction) {
        setRevealed(false)

        switch action {
        case .archive:
            onArchive()
        case .remove:
            onRemove()
        }
    }

    private func setRevealed(_ isRevealed: Bool) {
        withAnimation(.snappy(duration: 0.18)) {
            self.isRevealed = isRevealed
        }
    }
}

private enum ProjectBucketRowAction {
    case archive
    case remove

    var title: String {
        switch self {
        case .archive:
            return "Archive"
        case .remove:
            return "Remove"
        }
    }

    var menuTitle: String {
        switch self {
        case .archive:
            return "Archive Bucket"
        case .remove:
            return "Remove Bucket"
        }
    }

    var systemImage: String {
        switch self {
        case .archive:
            return "archivebox"
        case .remove:
            return "trash"
        }
    }

    var role: ButtonRole? {
        switch self {
        case .archive:
            return nil
        case .remove:
            return .destructive
        }
    }

    var background: Color {
        switch self {
        case .archive:
            return PikaColor.warning
        case .remove:
            return PikaColor.danger
        }
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
