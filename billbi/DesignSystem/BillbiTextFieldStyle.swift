import SwiftUI

struct BillbiTextFieldStyle: TextFieldStyle {
    @FocusState private var isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(BillbiColor.inputSurface)
            .clipShape(RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BillbiRadius.sm, style: .continuous)
                    .stroke(
                        isFocused ? BillbiColor.brandBorder : BillbiColor.border,
                        lineWidth: isFocused ? BillbiColor.inputFocusBorderWidth : 1
                    )
            }
    }
}

extension TextFieldStyle where Self == BillbiTextFieldStyle {
    static var billbiInput: BillbiTextFieldStyle {
        BillbiTextFieldStyle()
    }
}
