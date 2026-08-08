import SwiftUI

@main
@MainActor
struct PromptShelfApp: App {
    @StateObject private var store = PromptStore()

    var body: some Scene {
        MenuBarExtra("Prompt Shelf", systemImage: "text.quote") {
            PromptShelfRootView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
