import SwiftUI

struct OnboardingFixedSplit<Leading: View, Preview: View>: View {
    private static var leadingRatio: CGFloat { 0.42 }

    let leadingMinimumWidth: CGFloat
    let leading: Leading
    let preview: Preview

    init(
        leadingMinimumWidth: CGFloat,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder preview: () -> Preview
    ) {
        self.leadingMinimumWidth = leadingMinimumWidth
        self.leading = leading()
        self.preview = preview()
    }

    var body: some View {
        GeometryReader { proxy in
            let leadingWidth = fixedLeadingWidth(for: proxy.size.width)

            HStack(spacing: 0) {
                leading
                    .frame(width: leadingWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                Divider()

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    private func fixedLeadingWidth(for totalWidth: CGFloat) -> CGFloat {
        guard totalWidth > 0 else { return leadingMinimumWidth }

        let centeredWidth = totalWidth * Self.leadingRatio
        let maximumWidth = max(leadingMinimumWidth, totalWidth - 480)
        return min(max(centeredWidth, leadingMinimumWidth), maximumWidth)
    }
}
