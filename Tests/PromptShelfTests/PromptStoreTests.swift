import Foundation
import Testing
@testable import PromptShelf

@Suite("Prompt store")
struct PromptStoreTests {
    @Test("Drag reordering is persisted")
    @MainActor
    func dragReorderIsPersisted() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let first = PromptSnippet(title: "First", body: "1")
        let second = PromptSnippet(title: "Second", body: "2")
        let third = PromptSnippet(title: "Third", body: "3")
        let store = PromptStore(repository: repository, seedPrompts: [first, second, third])

        store.beginDragging(id: third.id)
        store.moveDraggedPrompt(to: first.id, afterTarget: false)
        store.finishDragging()
        store.flush()

        #expect(store.prompts.map(\.title) == ["Third", "First", "Second"])
        #expect(try repository.load()?.prompts.map(\.title) == ["Third", "First", "Second"])
    }

    @Test("Dragging downward reacts when the cursor crosses the target midpoint")
    @MainActor
    func downwardDragReordersAfterCrossingMidpoint() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let first = PromptSnippet(title: "First", body: "1")
        let second = PromptSnippet(title: "Second", body: "2")
        let third = PromptSnippet(title: "Third", body: "3")
        let store = PromptStore(repository: repository, seedPrompts: [first, second, third])

        store.beginDragging(id: first.id)
        store.moveDraggedPrompt(to: second.id, afterTarget: false)
        #expect(store.prompts.map(\.title) == ["First", "Second", "Third"])

        store.moveDraggedPrompt(to: second.id, afterTarget: true)
        store.finishDragging()
        store.flush()

        #expect(store.prompts.map(\.title) == ["Second", "First", "Third"])
        #expect(try repository.load()?.prompts.map(\.title) == ["Second", "First", "Third"])
    }

    @Test("Gesture reordering moves directly to a clamped index")
    @MainActor
    func gestureReorderMovesToClampedIndex() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let first = PromptSnippet(title: "First", body: "1")
        let second = PromptSnippet(title: "Second", body: "2")
        let third = PromptSnippet(title: "Third", body: "3")
        let store = PromptStore(repository: repository, seedPrompts: [first, second, third])

        store.beginDragging(id: first.id)
        store.movePrompt(id: first.id, to: 20)
        store.finishDragging()
        store.flush()

        #expect(store.prompts.map(\.title) == ["Second", "Third", "First"])
        #expect(try repository.load()?.prompts.map(\.title) == ["Second", "Third", "First"])
    }

    @Test("Drag preview does not mutate order until it is committed")
    @MainActor
    func dragPreviewCommitsOnce() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let first = PromptSnippet(title: "First", body: "1")
        let second = PromptSnippet(title: "Second", body: "2")
        let third = PromptSnippet(title: "Third", body: "3")
        let store = PromptStore(repository: repository, seedPrompts: [first, second, third])

        store.beginDragging(id: first.id)
        store.updateDragTarget(to: 2)

        #expect(store.prompts.map(\.title) == ["First", "Second", "Third"])
        #expect(store.dragOriginIndex == 0)
        #expect(store.dragTargetIndex == 2)

        store.commitDragging()
        store.flush()

        #expect(store.prompts.map(\.title) == ["Second", "Third", "First"])
        #expect(store.draggedPromptID == nil)
        #expect(store.dragOriginIndex == nil)
        #expect(store.dragTargetIndex == nil)
        #expect(try repository.load()?.prompts.map(\.title) == ["Second", "Third", "First"])
    }

    @Test("Editing content preserves the manually chosen order")
    @MainActor
    func editingContentPreservesOrder() {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let first = PromptSnippet(title: "First", body: "1")
        let second = PromptSnippet(title: "Second", body: "2")
        let third = PromptSnippet(title: "Third", body: "3")
        let store = PromptStore(repository: repository, seedPrompts: [first, second, third])

        store.update(id: second.id, title: "Edited", body: "Updated")

        #expect(store.prompts.map(\.title) == ["First", "Edited", "Third"])
    }

    @Test("Deleting removes only the selected prompt and persists")
    @MainActor
    func deletingPromptPersists() throws {
        let temporaryDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let repository = PromptRepository(directoryURL: temporaryDirectory)
        let first = PromptSnippet(title: "First", body: "1")
        let second = PromptSnippet(title: "Second", body: "2")
        let third = PromptSnippet(title: "Third", body: "3")
        let store = PromptStore(repository: repository, seedPrompts: [first, second, third])

        store.delete(id: second.id)
        store.flush()

        #expect(store.prompts.map(\.title) == ["First", "Third"])
        #expect(try repository.load()?.prompts.map(\.title) == ["First", "Third"])
    }

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
