import Foundation
@testable import billbi

enum WorkspaceFixtures {
    static let today = Date.billbiDate(year: 2026, month: 4, day: 27)

    #if DEBUG
    static let demoWorkspace = WorkspaceSeedLibrary.demoWorkspace
    static let bikeparkWorkspace = WorkspaceSeedLibrary.bikeparkThunersee
    #else
    static let demoWorkspace = WorkspaceSnapshot.empty
    static let bikeparkWorkspace = WorkspaceSnapshot.empty
    #endif

    static var demoBusinessProfile: BusinessProfileProjection {
        demoWorkspace.businessProfile
    }

    static var demoClients: [WorkspaceClient] {
        demoWorkspace.clients
    }
}
