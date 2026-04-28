import SwiftUI

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
