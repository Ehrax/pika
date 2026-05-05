import SwiftUI

struct CurrencyCodeField: View {
    let title: LocalizedStringKey
    @Binding var text: String

    init(_ title: LocalizedStringKey, text: Binding<String>) {
        self.title = title
        _text = text
    }

    var body: some View {
        TextField(title, text: normalizedText)
    }

    private var normalizedText: Binding<String> {
        Binding(
            get: { CurrencyTextFormatting.normalizedInput(text) },
            set: { text = CurrencyTextFormatting.normalizedInput($0) }
        )
    }
}
