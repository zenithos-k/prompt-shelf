import Foundation

enum PromptRepositoryError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            return "This prompt file uses unsupported schema version \(version)."
        case .invalidDocument:
            return "The selected file is not a valid Prompt Shelf document."
        }
    }
}

struct PromptRepository: Sendable {
    let directoryURL: URL
    let fileURL: URL

    init(directoryURL: URL? = nil) {
        let directory = directoryURL ?? Self.defaultDirectoryURL()
        self.directoryURL = directory
        self.fileURL = directory.appendingPathComponent("prompts.json", isDirectory: false)
    }

    func load() throws -> PromptDocument? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decodeDocument(at: fileURL)
    }

    func load(from sourceURL: URL) throws -> PromptDocument {
        try decodeDocument(at: sourceURL)
    }

    func save(_ document: PromptDocument) throws {
        try save(document, to: fileURL)
    }

    func save(_ document: PromptDocument, to destinationURL: URL) throws {
        let parent = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        try data.write(to: destinationURL, options: [.atomic])
    }

    private func decodeDocument(at url: URL) throws -> PromptDocument {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate

        guard let document = try? decoder.decode(PromptDocument.self, from: data) else {
            throw PromptRepositoryError.invalidDocument
        }

        guard document.schemaVersion <= PromptDocument.currentSchemaVersion else {
            throw PromptRepositoryError.unsupportedSchema(document.schemaVersion)
        }

        return document
    }

    private static func defaultDirectoryURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return applicationSupport.appendingPathComponent("PromptShelf", isDirectory: true)
    }
}
