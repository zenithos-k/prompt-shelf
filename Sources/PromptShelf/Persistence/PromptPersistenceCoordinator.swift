import Foundation

/// Serializes background saves so an older snapshot can never overwrite a newer one.
final class PromptPersistenceCoordinator: @unchecked Sendable {
    private let repository: PromptRepository
    private let queue = DispatchQueue(
        label: "com.kun.promptshelf.persistence",
        qos: .utility
    )

    init(repository: PromptRepository) {
        self.repository = repository
    }

    func save(_ document: PromptDocument) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [repository] in
                do {
                    try repository.save(document)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func saveSynchronously(_ document: PromptDocument) throws {
        var result: Result<Void, Error>!
        queue.sync { [repository] in
            result = Result {
                try repository.save(document)
            }
        }
        try result.get()
    }
}
