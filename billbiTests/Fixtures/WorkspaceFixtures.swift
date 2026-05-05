import Foundation
@testable import billbi

enum WorkspaceFixtures {
    static let today = Date.billbiDate(year: 2026, month: 4, day: 27)

    #if DEBUG
    static var demoWorkspace: WorkspaceSnapshot {
        detachedSnapshot(WorkspaceSeedLibrary.demoWorkspace)
    }

    static var bikeparkWorkspace: WorkspaceSnapshot {
        detachedSnapshot(WorkspaceSeedLibrary.bikeparkThunersee)
    }
    #else
    static var demoWorkspace: WorkspaceSnapshot {
        detachedSnapshot(.empty)
    }

    static var bikeparkWorkspace: WorkspaceSnapshot {
        detachedSnapshot(.empty)
    }
    #endif

    static var demoBusinessProfile: BusinessProfileProjection {
        demoWorkspace.businessProfile
    }

    static var demoClients: [WorkspaceClient] {
        demoWorkspace.clients
    }

    private static func detachedSnapshot(_ snapshot: WorkspaceSnapshot) -> WorkspaceSnapshot {
        do {
            let data = try JSONEncoder().encode(snapshot)
            return try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
        } catch {
            preconditionFailure("Workspace fixture could not be detached: \(error)")
        }
    }
}
