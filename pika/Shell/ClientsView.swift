import SwiftUI

struct ClientsView: View {
    let workspace: WorkspaceSnapshot

    var body: some View {
        ClientsFeatureView(workspace: workspace)
    }
}
