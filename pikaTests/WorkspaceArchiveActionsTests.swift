import Foundation
import Testing
@testable import pika

struct WorkspaceArchiveActionsTests {
    @Test func exportDestinationAppendsArchiveExtensionWhenMissing() {
        let selectedURL = URL(filePath: "/tmp/workspace-2026-05-02")

        let destinationURL = WorkspaceArchiveActions.exportDestinationURL(from: selectedURL)

        #expect(destinationURL.pathExtension == WorkspaceArchiveActions.fileExtension)
        #expect(destinationURL.lastPathComponent == "workspace-2026-05-02.\(WorkspaceArchiveActions.fileExtension)")
    }

    @Test func exportDestinationPreservesExistingArchiveExtensionCaseInsensitively() {
        let selectedURL = URL(filePath: "/tmp/workspace-2026-05-02.PIKAARCHIVE")

        let destinationURL = WorkspaceArchiveActions.exportDestinationURL(from: selectedURL)

        #expect(destinationURL == selectedURL)
    }
}
