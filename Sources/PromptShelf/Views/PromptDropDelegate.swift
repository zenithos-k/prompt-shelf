import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PromptDropDelegate: DropDelegate {
    let target: PromptSnippet
    let rowHeight: CGFloat
    let store: PromptStore

    func validateDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [UTType.text]),
              store.prompt(withID: store.draggedPromptID) != nil else { return false }
        return true
    }

    func dropEntered(info: DropInfo) {
        updatePosition(using: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        // `dropEntered` fires only once per row. Re-evaluate here so a cursor
        // moving from the top half to the bottom half can reorder downward.
        updatePosition(using: info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        let accepted = validateDrop(info: info)
        if accepted {
            updatePosition(using: info)
        }
        store.finishDragging()
        return accepted
    }

    private func updatePosition(using info: DropInfo) {
        guard validateDrop(info: info) else { return }
        store.moveDraggedPrompt(
            to: target.id,
            afterTarget: info.location.y >= rowHeight / 2
        )
    }
}
