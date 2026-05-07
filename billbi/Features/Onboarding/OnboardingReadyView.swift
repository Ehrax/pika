import SwiftUI

struct OnboardingReadyView: View {
    let workspace: WorkspaceSnapshot
    let summary: OnboardingReadySummary
    let onOpenApplication: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: BillbiSpacing.xl)
            VStack(alignment: .leading, spacing: BillbiSpacing.lg) {
                StatusBadge(summary.badgeState.statusTone, title: summary.badgeTitle)

                Text(summary.title)
                    .font(BillbiTypography.display)
                    .foregroundStyle(BillbiColor.textPrimary)
                Text(summary.subtitle)
                    .font(BillbiTypography.body)
                    .foregroundStyle(BillbiColor.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BillbiSpacing.md) {
                    ForEach(summary.cards, id: \.self) { card in
                        summaryCard(card)
                    }
                }
                .frame(maxWidth: .infinity)

                tips

                HStack {
                    Spacer(minLength: BillbiSpacing.xl)

                    Button("Open Application") {
                        onOpenApplication()
                    }
                    .buttonStyle(.billbiAction(.primary, size: .large))
                    .accessibilityIdentifier("Continue")
                }
                .padding(.top, BillbiSpacing.sm)
            }
            .frame(maxWidth: OnboardingReadyLayout.contentMaximumWidth, alignment: .leading)

            Spacer(minLength: BillbiSpacing.xl)
        }
        .padding(BillbiSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
            Text("NEXT")
                .font(BillbiTypography.micro)
                .foregroundStyle(BillbiColor.textSecondary)
            ForEach(summary.tips, id: \.self) { tip in
                Label(tip, systemImage: "circle")
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
        }
        .padding(BillbiSpacing.md)
        .frame(maxWidth: 760, alignment: .leading)
        .background(BillbiColor.surface, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }

    private func summaryCard(_ card: OnboardingSummaryCard) -> some View {
        let title: String
        let detail: String
        switch card {
        case .business:
            title = String(localized: "BUSINESS")
            detail = workspace.businessProfile.businessName
        case .client:
            title = String(localized: "CLIENT")
            detail = workspace.clients.first?.name ?? ""
        case .project:
            title = String(localized: "PROJECT")
            detail = workspace.activeProjects.first?.name ?? ""
        case .bucket:
            title = String(localized: "FIRST BUCKET")
            detail = workspace.activeProjects.first?.buckets.first?.name ?? ""
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BillbiTypography.micro)
                .foregroundStyle(BillbiColor.textSecondary)
            Text(detail)
                .font(BillbiTypography.subheading)
                .foregroundStyle(BillbiColor.textPrimary)
        }
        .padding(BillbiSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BillbiColor.surface, in: RoundedRectangle(cornerRadius: BillbiRadius.lg))
    }
}

private extension OnboardingReadyBadgeState {
    var statusTone: BillbiStatusTone {
        switch self {
        case .success:
            .success
        case .neutral:
            .neutral
        }
    }
}

private enum OnboardingReadyLayout {
    static let contentMaximumWidth: CGFloat = 640
}
