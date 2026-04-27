import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Pika")
                .font(.title)
                .foregroundStyle(.primary)

            Text("Scaffold ready")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    RootView()
}
