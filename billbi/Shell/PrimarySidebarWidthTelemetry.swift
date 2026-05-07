import SwiftUI

#if os(macOS)
struct PrimarySidebarWidthTelemetry: View {
    @Binding var storedWidth: Double

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    observe(width: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, newWidth in
                    observe(width: newWidth)
                }
        }
    }

    private func observe(width: CGFloat) {
        guard width > 1 else { return }

        let clampedWidth = PrimarySidebarColumnLayout.clamped(Double(width))
        if abs(storedWidth - clampedWidth) > 0.5 {
            storedWidth = clampedWidth
            UserDefaults.standard.set(clampedWidth, forKey: PrimarySidebarColumnLayout.widthStorageKey)
        }

        AppTelemetry.primarySidebarWidthObserved(width: clampedWidth)
    }
}
#endif
