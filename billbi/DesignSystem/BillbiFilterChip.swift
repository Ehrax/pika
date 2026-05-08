import SwiftUI

struct BillbiFilterChip: View {
    var title: String
    var count: Int?
    var tone: BillbiStatusTone?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(BillbiTypography.small.weight(isSelected ? .medium : .regular))
                    .lineLimit(1)

                if let count {
                    Text("\(count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .clipShape(chipShape)
            .contentShape(chipShape)
            .overlay {
                chipShape
                    .stroke(borderColor)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .accessibilityLabel(accessibilityLabel)
    }

    private var chipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BillbiRadius.pill)
    }

    private var foregroundColor: Color {
        if isSelected { return BillbiColor.onTint }
        if tone == nil { return BillbiColor.brand }
        return tone?.color ?? BillbiColor.textSecondary
    }

    private var backgroundColor: Color {
        if tone == nil {
            return isSelected ? BillbiColor.brand : BillbiColor.brandMuted
        }
        if isSelected {
            return tone == .neutral ? BillbiColor.textSecondary : tone?.color ?? BillbiColor.brand
        }
        return tone?.mutedColor ?? BillbiColor.surfaceAlt
    }

    private var borderColor: Color {
        if tone == nil {
            return isSelected ? BillbiColor.brand : BillbiColor.brandBorder
        }
        if isSelected {
            return tone == .neutral ? BillbiColor.textSecondary : tone?.color ?? BillbiColor.brand
        }
        return tone.map { $0.color.opacity(0.45) } ?? BillbiColor.border
    }

    private var accessibilityLabel: String {
        if let count {
            return "\(title): \(count)"
        }
        return title
    }
}
