import SwiftUI

struct ProjectWorkbenchEmptyBucketColumn: View {
    let project: WorkspaceProject
    let onCreateBucket: () -> Void

    var body: some View {
        BillbiSecondarySidebarColumn(
            title: project.name,
            subtitle: project.clientName,
            sectionTitle: "Buckets",
            wrapsContentInScrollView: false
        ) {
            Button {
                onCreateBucket()
            } label: {
                Label("Create a bucket", systemImage: "plus")
            }
            .buttonStyle(BillbiColumnHeaderIconButtonStyle(foreground: BillbiColor.brand))
            .help("Create a bucket")
        } controls: {
            EmptyView()
        } content: {
            VStack(spacing: 0) {
                Divider()
                List { EmptyView() }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(BillbiColor.surface)
                    .padding(.top, BillbiSpacing.md)
            }
        }
    }
}
