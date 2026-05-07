import SwiftUI

struct BillbiFilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BillbiTypography.small.weight(isSelected ? .medium : .regular))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : BillbiColor.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isSelected ? BillbiColor.brand : BillbiColor.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.pill))
        .overlay {
            RoundedRectangle(cornerRadius: BillbiRadius.pill)
                .stroke(isSelected ? BillbiColor.brand : BillbiColor.border)
        }
    }
}
