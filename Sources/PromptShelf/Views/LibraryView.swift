import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: PromptStore
    @Environment(\.colorScheme) private var colorScheme
    let appearanceMode: AppearanceMode
    let onCycleAppearance: () -> Void
    let onOpenSettings: () -> Void
    let onAdd: () -> Void
    let onEdit: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onSelect: (PromptSnippet) -> Void

    @State private var searchText = ""
    @State private var pendingDeletion: PromptSnippet?
    @FocusState private var searchIsFocused: Bool

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visiblePrompts: [PromptSnippet] {
        filter(store.prompts)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, ShelfColors.azure.opacity(0.24), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                if visiblePrompts.isEmpty {
                    emptyState
                } else {
                    promptList
                }

                footer
            }
            .allowsHitTesting(pendingDeletion == nil)

            if let pendingDeletion {
                deleteConfirmation(for: pendingDeletion)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.15), value: pendingDeletion?.id)
    }

    private var header: some View {
        VStack(spacing: 0) {
            toolbar

            searchField
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
        .background { ShelfChromeBackground() }
    }

    private var toolbar: some View {
        HStack(spacing: 9) {
            AppMarkView(size: 38)

            Text("Prompt Shelf")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(height: 38, alignment: .center)

            Spacer()

            Button(action: onCycleAppearance) {
                Image(systemName: colorScheme == .dark ? "moon.stars.fill" : "sun.max.fill")
                    .accessibilityLabel("Toggle appearance")
            }
            .buttonStyle(ShelfIconButtonStyle())
            .help(
                "Currently using \(colorScheme == .dark ? "dark" : "light") appearance (setting: \(appearanceMode.displayName)). Click to toggle."
            )

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
            }
            .buttonStyle(ShelfIconButtonStyle())
            .help("Settings")

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .accessibilityLabel("New Prompt")
            }
            .buttonStyle(ShelfIconButtonStyle())
            .help("New Prompt")
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(colorScheme == .light ? ShelfColors.azure.opacity(0.72) : Color.secondary)

            TextField("Search titles or content", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchIsFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .shelfCard(
            cornerRadius: 12,
            tint: searchIsFocused ? ShelfColors.azure : ShelfColors.indigo,
            elevated: searchIsFocused
        )
        .animation(.easeOut(duration: 0.16), value: searchIsFocused)
    }

    private var promptList: some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                ForEach(visiblePrompts) { prompt in
                    row(prompt)
                        .id(prompt.id)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
        }
        .scrollDisabled(store.draggedPromptID != nil)
        .animation(
            store.draggedPromptID == nil ? .easeInOut(duration: 0.18) : nil,
            value: store.prompts.map(\.id)
        )
    }

    private func row(_ prompt: PromptSnippet) -> some View {
        PromptRow(
            prompt: prompt,
            store: store,
            isReorderingEnabled: normalizedQuery.isEmpty,
            onCopy: { onSelect(prompt) },
            onEdit: { onEdit(prompt.id) },
            onDelete: { pendingDeletion = prompt }
        )
    }

    private func deleteConfirmation(for prompt: PromptSnippet) -> some View {
        ZStack {
            Color.black
                .opacity(colorScheme == .dark ? 0.34 : 0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    pendingDeletion = nil
                }

            VStack(spacing: 16) {
                Image(systemName: "trash")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.1), in: Circle())

                Text("Are you sure you want to delete “\(prompt.title)”?")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        pendingDeletion = nil
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Delete", role: .destructive) {
                        pendingDeletion = nil
                        onDelete(prompt.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
            .padding(20)
            .frame(width: 310)
            .shelfCard(
                cornerRadius: 18,
                tint: .red,
                tintOpacity: 0.035,
                elevated: true
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: normalizedQuery.isEmpty ? "text.quote" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(normalizedQuery.isEmpty ? "No prompts yet" : "No matches")
                .font(.headline)
            Text(normalizedQuery.isEmpty ? "Click + in the top-right corner to create one" : "Try a different search")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
            Text(normalizedQuery.isEmpty ? "Drag a handle to reorder" : "Clear search to reorder")
            Spacer()
            Text("Click a prompt to copy")
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background { ShelfChromeBackground() }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    colorScheme == .light
                        ? ShelfColors.warmLine.opacity(0.42)
                        : Color(nsColor: .separatorColor).opacity(0.35)
                )
                .frame(height: 0.5)
        }
    }

    private func filter(_ prompts: [PromptSnippet]) -> [PromptSnippet] {
        guard !normalizedQuery.isEmpty else { return prompts }
        return prompts.filter {
            $0.title.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.body.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }
}
