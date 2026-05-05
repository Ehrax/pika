import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ResizableDetailSplitView<Leading: View, Detail: View>: View {
    private let leading: Leading
    private let detail: Detail
    @AppStorage(ResizableDetailSplitLayout.leadingWidthStorageKey) private var storedLeadingWidth = ResizableDetailSplitLayout.leadingIdealWidth

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder detail: () -> Detail
    ) {
        self.leading = leading()
        self.detail = detail()
    }

    var body: some View {
        #if os(macOS)
        MacDetailSplitView(
            leadingWidth: $storedLeadingWidth,
            leadingMinimumWidth: CGFloat(ResizableDetailSplitLayout.leadingMinimumWidth),
            leadingIdealWidth: CGFloat(ResizableDetailSplitLayout.leadingIdealWidth),
            leadingMaximumWidth: CGFloat(ResizableDetailSplitLayout.leadingMaximumWidth),
            detailMinimumWidth: CGFloat(ResizableDetailSplitLayout.detailMinimumWidth),
            leading: leading,
            detail: detail
        )
        .ignoresSafeArea(.container, edges: .top)
        #else
        HStack(spacing: 0) {
            leading
            detail
        }
        #endif
    }
}

struct ResizableDetailSplitLayout: Equatable {
    static let leadingMinimumWidth = 240.0
    static let leadingIdealWidth = 403.0
    static let leadingMaximumWidth = 720.0
    static let detailMinimumWidth = 520.0
    static let leadingWidthStorageKey = "billbi.resizableDetailSplit.leadingWidth"

    static func clampedLeadingWidth(_ width: Double) -> Double {
        min(max(width, leadingMinimumWidth), leadingMaximumWidth)
    }
}

#if os(macOS)
private struct MacDetailSplitView<Leading: View, Detail: View>: NSViewRepresentable {
    @Binding var leadingWidth: Double
    let leadingMinimumWidth: CGFloat
    let leadingIdealWidth: CGFloat
    let leadingMaximumWidth: CGFloat
    let detailMinimumWidth: CGFloat
    let leading: Leading
    let detail: Detail

    func makeCoordinator() -> Coordinator {
        Coordinator(
            leadingWidth: $leadingWidth,
            leadingMinimumWidth: leadingMinimumWidth,
            leadingIdealWidth: leadingIdealWidth,
            leadingMaximumWidth: leadingMaximumWidth,
            detailMinimumWidth: detailMinimumWidth
        )
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        let leadingHost = NSHostingView(rootView: leading)
        let detailHost = NSHostingView(rootView: detail)
        leadingHost.translatesAutoresizingMaskIntoConstraints = false
        detailHost.translatesAutoresizingMaskIntoConstraints = false

        splitView.addArrangedSubview(leadingHost)
        splitView.addArrangedSubview(detailHost)
        splitView.setHoldingPriority(.init(260), forSubviewAt: 0)
        splitView.setHoldingPriority(.init(200), forSubviewAt: 1)

        context.coordinator.leadingHost = leadingHost
        context.coordinator.detailHost = detailHost
        context.coordinator.applyInitialPosition(to: splitView)

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.leadingHost?.rootView = leading
        context.coordinator.detailHost?.rootView = detail
        context.coordinator.applyInitialPosition(to: splitView)
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        @Binding private var leadingWidth: Double
        private let leadingMinimumWidth: CGFloat
        private let leadingIdealWidth: CGFloat
        private let leadingMaximumWidth: CGFloat
        private let detailMinimumWidth: CGFloat
        private var didApplyInitialPosition = false
        weak var leadingHost: NSHostingView<Leading>?
        weak var detailHost: NSHostingView<Detail>?

        init(
            leadingWidth: Binding<Double>,
            leadingMinimumWidth: CGFloat,
            leadingIdealWidth: CGFloat,
            leadingMaximumWidth: CGFloat,
            detailMinimumWidth: CGFloat
        ) {
            _leadingWidth = leadingWidth
            self.leadingMinimumWidth = leadingMinimumWidth
            self.leadingIdealWidth = leadingIdealWidth
            self.leadingMaximumWidth = leadingMaximumWidth
            self.detailMinimumWidth = detailMinimumWidth
        }

        func applyInitialPosition(to splitView: NSSplitView) {
            guard !didApplyInitialPosition else { return }

            DispatchQueue.main.async { [weak self, weak splitView] in
                guard let self, let splitView else { return }

                let preferredWidth = self.clampedLeadingWidth(
                    self.leadingWidth > 0 ? self.leadingWidth : Double(self.leadingIdealWidth)
                )
                splitView.setPosition(preferredWidth, ofDividerAt: 0)
                self.didApplyInitialPosition = true
                self.leadingWidth = Double(preferredWidth)
                UserDefaults.standard.set(Double(preferredWidth), forKey: ResizableDetailSplitLayout.leadingWidthStorageKey)
                AppTelemetry.secondarySidebarWidthObserved(width: Double(preferredWidth), event: "restored")
            }
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMinCoordinate proposedMinimumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            leadingMinimumWidth
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMaxCoordinate proposedMaximumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let maximumAllowedByDetail = max(leadingMinimumWidth, splitView.bounds.width - detailMinimumWidth)
            return min(leadingMaximumWidth, maximumAllowedByDetail)
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard didApplyInitialPosition else { return }
            guard
                let splitView = notification.object as? NSSplitView,
                let leadingSubview = splitView.arrangedSubviews.first
            else {
                return
            }

            leadingWidth = Double(clampedLeadingWidth(leadingSubview.frame.width))
            UserDefaults.standard.set(leadingWidth, forKey: ResizableDetailSplitLayout.leadingWidthStorageKey)
            AppTelemetry.secondarySidebarWidthObserved(width: leadingWidth, event: "resized")
        }

        private func clampedLeadingWidth(_ width: Double) -> CGFloat {
            clampedLeadingWidth(CGFloat(width))
        }

        private func clampedLeadingWidth(_ width: CGFloat) -> CGFloat {
            min(max(width, leadingMinimumWidth), leadingMaximumWidth)
        }
    }
}
#endif
