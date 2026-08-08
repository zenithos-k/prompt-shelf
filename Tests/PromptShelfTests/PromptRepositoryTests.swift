import Foundation
import Testing
@testable import PromptShelf

@Suite("Prompt repository")
struct PromptRepositoryTests {
    @Test("Round trip preserves order and metadata")
    func roundTripPreservesOrderAndMetadata() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let prompts = [
            PromptSnippet(title: "One", body: "First"),
            PromptSnippet(title: "Two", body: "Second")
        ]

        try repository.save(PromptDocument(prompts: prompts))
        let loaded = try #require(try repository.load())

        #expect(loaded.prompts == prompts)
    }

    @Test("Legacy pinned documents preserve order and ignore the obsolete flag")
    func legacyPinnedDocumentPreservesOrder() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let legacyDocument = """
        {
          "schemaVersion": 1,
          "prompts": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "title": "Previously pinned",
              "body": "First",
              "isPinned": true,
              "createdAt": 0,
              "updatedAt": 0
            },
            {
              "id": "22222222-2222-2222-2222-222222222222",
              "title": "Regular",
              "body": "Second",
              "isPinned": false,
              "createdAt": 0,
              "updatedAt": 0
            }
          ]
        }
        """
        try Data(legacyDocument.utf8).write(to: repository.fileURL)

        let loaded = try #require(try repository.load())

        #expect(loaded.prompts.map(\.title) == ["Previously pinned", "Regular"])
    }

    @Test("Invalid files produce a readable error")
    func invalidFileProducesReadableError() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        let repository = PromptRepository(directoryURL: temporaryDirectory)
        try Data("not json".utf8).write(to: repository.fileURL)

        #expect(throws: PromptRepositoryError.invalidDocument) {
            try repository.load()
        }
    }

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
