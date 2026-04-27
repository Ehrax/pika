import Foundation

enum SheetDestination: Hashable, Identifiable {
    case projectEditor(id: UUID?)

    var id: String {
        switch self {
        case .projectEditor(let projectID):
            if let projectID {
                return "projectEditor-\(projectID.uuidString)"
            }

            return "projectEditor-new"
        }
    }
}
