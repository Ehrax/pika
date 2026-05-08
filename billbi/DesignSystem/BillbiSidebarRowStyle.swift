import SwiftUI

private struct BillbiSecondarySidebarRowModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(isSelected ? BillbiColor.brandMuted : Color.clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(BillbiColor.brand)
                        .frame(width: 3)
                        .padding(.vertical, 9)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.md))
    }
}

extension View {
    func billbiSecondarySidebarRow(isSelected: Bool) -> some View {
        modifier(BillbiSecondarySidebarRowModifier(isSelected: isSelected))
    }
}
