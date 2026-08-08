import Foundation

struct PromptSnippet: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct PromptDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var prompts: [PromptSnippet]

    init(
        schemaVersion: Int = PromptDocument.currentSchemaVersion,
        prompts: [PromptSnippet]
    ) {
        self.schemaVersion = schemaVersion
        self.prompts = prompts
    }
}
