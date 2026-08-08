import Foundation

@MainActor
final class PromptStore: ObservableObject {
    @Published private(set) var prompts: [PromptSnippet]
    @Published private(set) var draggedPromptID: UUID?
    @Published private(set) var dragOriginIndex: Int?
    @Published private(set) var dragTargetIndex: Int?
    @Published var lastError: String?

    private let repository: PromptRepository
    private let persistence: PromptPersistenceCoordinator
    private var saveTask: Task<Void, Never>?
    private var isDirty = false
    private var revision: UInt64 = 0

    init(
        repository: PromptRepository = PromptRepository(),
        seedPrompts: [PromptSnippet]? = nil
    ) {
        self.repository = repository
        self.persistence = PromptPersistenceCoordinator(repository: repository)

        do {
            if let document = try repository.load() {
                self.prompts = document.prompts
            } else {
                self.prompts = seedPrompts ?? Self.defaultPrompts
                try repository.save(PromptDocument(prompts: self.prompts))
            }
        } catch {
            self.prompts = seedPrompts ?? Self.defaultPrompts
            self.lastError = error.localizedDescription
        }
    }

    deinit {
        saveTask?.cancel()
    }

    var databaseURL: URL {
        repository.fileURL
    }

    func prompt(withID id: UUID?) -> PromptSnippet? {
        guard let id else { return nil }
        return prompts.first { $0.id == id }
    }

    @discardableResult
    func add(title: String, body: String) -> UUID {
        let snippet = PromptSnippet(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        prompts.append(snippet)

        scheduleSave()
        return snippet.id
    }

    func update(id: UUID, title: String, body: String) {
        guard let index = prompts.firstIndex(where: { $0.id == id }) else { return }
        var snippet = prompts[index]
        snippet.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet.updatedAt = Date()
        prompts[index] = snippet

        scheduleSave()
    }

    func delete(id: UUID) {
        prompts.removeAll { $0.id == id }
        if draggedPromptID == id {
            finishDragging()
        }
        scheduleSave()
    }

    func beginDragging(id: UUID) {
        guard let index = index(of: id) else { return }
        draggedPromptID = id
        dragOriginIndex = index
        dragTargetIndex = index
    }

    func updateDragTarget(to proposedIndex: Int) {
        guard draggedPromptID != nil, !prompts.isEmpty else { return }
        let target = min(max(proposedIndex, prompts.startIndex), prompts.index(before: prompts.endIndex))
        guard dragTargetIndex != target else { return }
        dragTargetIndex = target
    }

    func commitDragging() {
        guard let draggedPromptID, let dragTargetIndex else {
            finishDragging()
            return
        }

        movePrompt(id: draggedPromptID, to: dragTargetIndex)
        finishDragging()
    }

    func index(of id: UUID) -> Int? {
        prompts.firstIndex { $0.id == id }
    }

    func movePrompt(id: UUID, to proposedIndex: Int) {
        guard prompts.count > 1,
              let sourceIndex = prompts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let destinationIndex = min(max(proposedIndex, prompts.startIndex), prompts.index(before: prompts.endIndex))
        guard sourceIndex != destinationIndex else { return }

        let snippet = prompts.remove(at: sourceIndex)
        prompts.insert(snippet, at: min(destinationIndex, prompts.endIndex))
        scheduleSave()
    }

    func moveDraggedPrompt(to targetID: UUID, afterTarget: Bool) {
        guard let draggedPromptID,
              draggedPromptID != targetID,
              let sourceIndex = prompts.firstIndex(where: { $0.id == draggedPromptID }),
              let originalTargetIndex = prompts.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let targetIndexAfterRemoval = originalTargetIndex - (sourceIndex < originalTargetIndex ? 1 : 0)
        let insertionIndex = targetIndexAfterRemoval + (afterTarget ? 1 : 0)
        guard insertionIndex != sourceIndex else { return }

        let snippet = prompts.remove(at: sourceIndex)
        prompts.insert(snippet, at: min(insertionIndex, prompts.endIndex))
        scheduleSave()
    }

    func finishDragging() {
        guard draggedPromptID != nil else { return }
        draggedPromptID = nil
        dragOriginIndex = nil
        dragTargetIndex = nil
    }

    func export(to url: URL) throws {
        flush()
        try repository.save(PromptDocument(prompts: prompts), to: url)
    }

    func importDocument(from url: URL) throws {
        let document = try repository.load(from: url)
        prompts = Self.removingDuplicateIDs(document.prompts)
        scheduleSave()
    }

    func flush() {
        guard isDirty else { return }
        saveTask?.cancel()
        saveTask = nil
        revision &+= 1

        do {
            try persistence.saveSynchronously(PromptDocument(prompts: prompts))
            isDirty = false
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearError() {
        lastError = nil
    }

    private func scheduleSave() {
        isDirty = true
        revision &+= 1
        let scheduledRevision = revision
        saveTask?.cancel()
        let document = PromptDocument(prompts: prompts)
        let persistence = persistence

        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 160_000_000)
                try Task.checkCancellation()
                try await persistence.save(document)
                guard !Task.isCancelled else { return }
                guard self?.revision == scheduledRevision else { return }
                self?.isDirty = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.lastError = error.localizedDescription
            }
        }
    }

    private static func removingDuplicateIDs(_ source: [PromptSnippet]) -> [PromptSnippet] {
        var seen = Set<UUID>()
        return source.map { snippet in
            guard !seen.insert(snippet.id).inserted else { return snippet }
            var copy = snippet
            copy.id = UUID()
            return copy
        }
    }

    static let defaultPrompts: [PromptSnippet] = [
        PromptSnippet(
            title: "Review current changes",
            body: "Review the current git diff. Prioritize correctness, regressions, security, and missing tests. Cite each relevant file and line."
        ),
        PromptSnippet(
            title: "Create an implementation plan",
            body: "Read the relevant code first. List the goal, affected components, key decisions, validation steps, and risks. Do not edit files before I approve the plan."
        ),
        PromptSnippet(
            title: "Explain this code",
            body: "Explain the implementation in {{file}}, focusing on {{topic}}. Start with the overall flow, then cover key functions, data structures, and edge cases."
        ),
        PromptSnippet(
            title: "Fix and verify",
            body: "Find the root cause, implement the smallest safe fix, then run {{test_command}}. Avoid unrelated changes."
        ),
        PromptSnippet(
            title: "Draft a commit message",
            body: "Write a concise commit message from the current diff. Use a result-oriented subject, then bullets for the important changes and verification."
        )
    ]
}
