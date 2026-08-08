import SwiftUI

@main
@MainActor
struct PromptShelfApp: App {
    @StateObject private var store = PromptStore()

    var body: some Scene {
        MenuBarExtra {
            PromptShelfRootView(store: store)
        } label: {
            Image(systemName: "text.quote")
                .symbolRenderingMode(.monochrome)
                .environment(\.colorScheme, .light)
                .accessibilityLabel("Prompt Shelf")
        }
        .menuBarExtraStyle(.window)
    }
}
