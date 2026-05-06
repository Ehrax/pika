import SwiftUI

struct StatusBadge: View {
    var tone: BillbiStatusTone
    var title: String

    init(_ tone: BillbiStatusTone, title: String) {
        self.tone = tone
        self.title = title
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(BillbiTypography.small)
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, BillbiSpacing.sm)
        .padding(.vertical, BillbiSpacing.xs)
        .background(tone.mutedColor)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
        .accessibilityLabel("\(tone.accessibilityLabel): \(title)")
    }
}

struct SectionHeader: View {
    var title: String
    var detail: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(BillbiTypography.subheading)
                .foregroundStyle(BillbiColor.textPrimary)
            if !detail.isEmpty {
                Spacer()
                Text(detail)
                    .font(BillbiTypography.small)
                    .foregroundStyle(BillbiColor.textSecondary)
            }
        }
        .padding(.bottom, BillbiSpacing.xs)
    }
}

extension View {
    func billbiSurface() -> some View {
        background(BillbiColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.lg)
                    .stroke(BillbiColor.border)
            }
    }
}
