import SwiftUI

struct ResizableDetailSplitView<Leading: View, Detail: View>: View {
    private let leading: Leading
    private let detail: Detail
    @SceneStorage("pika.resizableDetailSplit.leadingWidth") private var storedLeadingWidth = Self.defaultLeadingWidth
    @State private var dragStartWidth: CGFloat?

    private static var defaultLeadingWidth: Double { 500 }
    private static var minimumLeadingWidth: CGFloat { 320 }
    private static var maximumLeadingWidth: CGFloat { 620 }
    private static var minimumDetailWidth: CGFloat { 460 }

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder detail: () -> Detail
    ) {
        self.leading = leading()
        self.detail = detail()
    }

    var body: some View {
        #if os(macOS)
        GeometryReader { proxy in
            let leadingWidth = clampedLeadingWidth(for: proxy.size.width)

            HStack(spacing: 0) {
                leading
                    .frame(width: leadingWidth)

                splitHandle(containerWidth: proxy.size.width)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                storedLeadingWidth = leadingWidth
            }
        }
        #else
        HStack(spacing: 0) {
            leading
            detail
        }
        #endif
    }

    #if os(macOS)
    private func splitHandle(containerWidth: CGFloat) -> some View {
        Rectangle()
            .fill(PikaColor.border)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle().inset(by: -4))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let startingWidth = dragStartWidth ?? clampedLeadingWidth(for: containerWidth)
                        dragStartWidth = startingWidth
                        storedLeadingWidth = Double(clamped(
                            startingWidth + value.translation.width,
                            containerWidth: containerWidth
                        ))
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
    }

    private func clampedLeadingWidth(for containerWidth: CGFloat) -> CGFloat {
        clamped(CGFloat(storedLeadingWidth), containerWidth: containerWidth)
    }

    private func clamped(_ width: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let availableMaximum = max(
            Self.minimumLeadingWidth,
            min(Self.maximumLeadingWidth, containerWidth - Self.minimumDetailWidth)
        )
        return min(max(width, Self.minimumLeadingWidth), availableMaximum)
    }
    #endif
}
