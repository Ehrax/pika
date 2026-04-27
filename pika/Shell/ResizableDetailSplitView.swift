import SwiftUI

struct ResizableDetailSplitView<Leading: View, Detail: View>: View {
    private let leading: Leading
    private let detail: Detail

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder detail: () -> Detail
    ) {
        self.leading = leading()
        self.detail = detail()
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            leading
            detail
        }
        #else
        HStack(spacing: 0) {
            leading
            detail
        }
        #endif
    }
}
