import Foundation
import SwiftData

@Model
final class Snippet {
    var id: UUID
    var title: String
    var command: String
    var category: String?
    var createdAt: Date
    var updatedAt: Date
    var usageCount: Int

    init(
        title: String,
        command: String,
        category: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.command = command
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
        self.usageCount = 0
    }
}
