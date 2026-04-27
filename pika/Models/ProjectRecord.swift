import Foundation
import SwiftData

@Model
final class ProjectRecord {
    var id: UUID
    var title: String
    var createdAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}
