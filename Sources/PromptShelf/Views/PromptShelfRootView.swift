import AppKit
import SwiftUI

private enum ShelfRoute: Equatable {
    case library
    case editor(UUID?)
    case variables(UUID)
    case settings
}

struct PromptShelfRootView: View {
    @ObservedObject var store: PromptStore
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(PreferenceKey.appearanceMode)
    private var appearanceRawValue = AppearanceMode.system.rawValue

    @AppStorage(PreferenceKey.closeAfterCopy)
    private var closeAfterCopy = false

    @State private var route: ShelfRoute = .library
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceRawValue) ?? .system
    }

    var body: some View {
        ZStack(alignment: .top) {
            background

            content

            if let toastMessage {
                Label(toastMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .shelfGlassSurface(cornerRadius: 12)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(width: 460, height: 640)
        .preferredColorScheme(appearanceMode.colorScheme)
        .background {
            WindowVisibilityObserver(onHidden: resetForNextPresentation)
                .frame(width: 0, height: 0)
        }
        .alert("Unable to Save Prompt", isPresented: storeErrorBinding) {
            Button("OK", role: .cancel) {
                store.clearError()
            }
        } message: {
            Text(store.lastError ?? "Unknown error")
        }
        .onDisappear {
            resetForNextPresentation()
        }
        .onAppear {
            AppAppearanceController.apply(appearanceMode)
        }
        .onChange(of: appearanceRawValue) { newValue in
            AppAppearanceController.apply(AppearanceMode(rawValue: newValue) ?? .system)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.flush()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .library:
            LibraryView(
                store: store,
                appearanceMode: appearanceMode,
                onCycleAppearance: cycleAppearance,
                onOpenSettings: { route = .settings },
                onAdd: { route = .editor(nil) },
                onEdit: { route = .editor($0) },
                onDelete: { id in
                    store.delete(id: id)
                    showToast("Deleted")
                },
                onSelect: selectPrompt
            )

        case let .editor(promptID):
            let prompt = store.prompt(withID: promptID)
            PromptEditorView(
                prompt: prompt,
                onCancel: { route = .library },
                onSave: { title, body in
                    if let promptID {
                        store.update(id: promptID, title: title, body: body)
                    } else {
                        store.add(title: title, body: body)
                    }
                    route = .library
                    showToast("Saved")
                },
                onDelete: promptID.map { id in
                    {
                        store.delete(id: id)
                        route = .library
                        showToast("Deleted")
                    }
                }
            )
            .id(promptID)

        case let .variables(promptID):
            if let prompt = store.prompt(withID: promptID) {
                VariableFillView(
                    prompt: prompt,
                    onCancel: { route = .library },
                    onCopy: { value in
                        route = .library
                        copyToClipboard(value)
                    }
                )
            } else {
                unavailablePrompt
            }

        case .settings:
            SettingsView(store: store) {
                route = .library
            }
        }
    }

    private var background: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)

            RadialGradient(
                colors: [
                    ShelfColors.azure.opacity(colorScheme == .dark ? 0.24 : 0.16),
                    ShelfColors.indigo.opacity(colorScheme == .dark ? 0.09 : 0.055),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 390
            )

            RadialGradient(
                colors: [
                    ShelfColors.violet.opacity(colorScheme == .dark ? 0.15 : 0.09),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 330
            )

            LinearGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.028 : 0.2),
                    .clear,
                    Color.black.opacity(colorScheme == .dark ? 0.1 : 0.015)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var unavailablePrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("This prompt no longer exists")
            Button("Back") { route = .library }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var storeErrorBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil },
            set: { visible in
                if !visible { store.clearError() }
            }
        )
    }

    private func selectPrompt(_ prompt: PromptSnippet) {
        if PromptTemplate.variables(in: prompt.body).isEmpty {
            copyToClipboard(prompt.body)
        } else {
            route = .variables(prompt.id)
        }
    }

    private func copyToClipboard(_ value: String) {
        guard ClipboardService.copy(value) else {
            store.lastError = "Unable to write to the clipboard."
            return
        }

        showToast("Copied to Clipboard")
        if closeAfterCopy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                MenuBarWindowController.dismiss()
            }
        }
    }

    private func cycleAppearance() {
        let target: AppearanceMode = colorScheme == .dark ? .light : .dark
        appearanceRawValue = target.rawValue
        AppAppearanceController.apply(target)
    }

    private func resetForNextPresentation() {
        toastTask?.cancel()
        toastTask = nil
        toastMessage = nil
        route = .library
        store.finishDragging()
        store.flush()
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            toastMessage = message
        }

        toastTask = Task {
            do {
                try await Task.sleep(nanoseconds: 1_250_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.14)) {
                        toastMessage = nil
                    }
                }
            } catch {
                return
            }
        }
    }
}
