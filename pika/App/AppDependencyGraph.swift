import SwiftUI

private struct PikaDependencyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func pikaDependencies() -> some View {
        modifier(PikaDependencyModifier())
    }
}

extension Scene {
    func pikaDependencies() -> some Scene {
        self
    }
}
