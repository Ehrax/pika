import SwiftUI

struct AttentionRow: View {
    var item: DashboardAttentionItem
    var amount: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: BillbiSpacing.md) {
                badge

                inlineDescription
                    .layoutPriority(1)

                Spacer(minLength: BillbiSpacing.sm)

                amountText
            }
            .padding(BillbiSpacing.md)

            VStack(alignment: .leading, spacing: BillbiSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: BillbiSpacing.md) {
                    badge
                    Spacer(minLength: BillbiSpacing.sm)
                    amountText
                }

                inlineDescription
            }
            .padding(BillbiSpacing.md)
        }
    }

    private var badge: some View {
        StatusBadge(item.tone, title: item.tone == .danger ? "Overdue" : "Ready")
            .fixedSize(horizontal: true, vertical: false)
    }

    private var inlineDescription: some View {
        HStack(alignment: .firstTextBaseline, spacing: BillbiSpacing.xs) {
            Text(item.title)
                .font(BillbiTypography.body.weight(.medium))
                .foregroundStyle(BillbiColor.textPrimary)
                .lineLimit(1)

            Text(item.detail)
                .font(BillbiTypography.small)
                .foregroundStyle(BillbiColor.textSecondary)
                .lineLimit(1)
        }
        .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
    }

    private var amountText: some View {
        Text(amount)
            .font(BillbiTypography.body.monospacedDigit())
            .foregroundStyle(BillbiColor.textPrimary)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: true, vertical: false)
    }
}
