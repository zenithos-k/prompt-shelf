import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: PromptStore
    let onDone: () -> Void

    @AppStorage(PreferenceKey.appearanceMode)
    private var appearanceRawValue = AppearanceMode.system.rawValue

    @AppStorage(PreferenceKey.closeAfterCopy)
    private var closeAfterCopy = false

    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @State private var pendingImportURL: URL?
    @State private var showsImportConfirmation = false
    @State private var localError: String?

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRawValue) ?? .system },
            set: { mode in
                appearanceRawValue = mode.rawValue
                AppAppearanceController.apply(mode)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)

            ScrollView {
                VStack(spacing: 14) {
                    appearanceSection
                    behaviorSection
                    dataSection
                    aboutSection
                }
                .padding(16)
            }

            Divider().opacity(0.55)
            HStack {
                Button("Quit Prompt Shelf", role: .destructive) {
                    store.flush()
                    NSApp.terminate(nil)
                }
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(.ultraThinMaterial)
        }
        .onAppear { launchAtLogin.refresh() }
        .alert("Unable to Complete the Operation", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                localError = nil
                launchAtLogin.errorMessage = nil
            }
        } message: {
            Text(localError ?? launchAtLogin.errorMessage ?? "Unknown error")
        }
        .confirmationDialog(
            "Importing Replaces Current Prompts",
            isPresented: $showsImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("Import and Replace", role: .destructive) {
                performImport()
            }
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("Export a backup first. The imported file's prompt order will be preserved.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onDone) {
                Image(systemName: "chevron.left")
                    .accessibilityLabel("Back")
            }
            .buttonStyle(ShelfIconButtonStyle())
            .keyboardShortcut(.cancelAction)

            VStack(alignment: .leading, spacing: 1) {
                Text("Settings")
                    .font(.system(size: 15, weight: .bold))
                Text("Appearance, behavior, and local data")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private var appearanceSection: some View {
        settingsCard(
            title: "Appearance",
            systemImage: "circle.lefthalf.filled",
            tint: ShelfColors.indigo
        ) {
            Picker("Display mode", selection: appearanceBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("System follows your current macOS light or dark appearance.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private var behaviorSection: some View {
        settingsCard(title: "Behavior", systemImage: "switch.2", tint: ShelfColors.azure) {
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            .toggleStyle(.switch)

            if launchAtLogin.needsApproval {
                Text("Approval is required in System Settings → General → Login Items.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
            }

            Divider()

            Toggle("Close Window After Copying", isOn: $closeAfterCopy)
                .toggleStyle(.switch)
        }
    }

    private var dataSection: some View {
        settingsCard(title: "Data", systemImage: "externaldrive", tint: ShelfColors.violet) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local JSON")
                        .font(.system(size: 12, weight: .medium))
                    Text(store.databaseURL.path)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                Spacer()
                Button("Show in Finder") {
                    store.flush()
                    NSWorkspace.shared.activateFileViewerSelecting([store.databaseURL])
                }
            }

            Divider()

            HStack {
                Button("Import…", action: chooseImportFile)
                Button("Export…", action: exportDocument)
                Spacer()
                Label("Stored only on this Mac", systemImage: "lock")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        settingsCard(title: "About", systemImage: "info.circle", tint: ShelfColors.indigo) {
            HStack {
                Text("Prompt Shelf")
                Spacer()
                Text("Version \(appVersion)")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11.5))

            Text("A native macOS menu bar prompt manager with automatic variable detection, drag-and-drop ordering, and local backups.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .shelfCard(cornerRadius: 12, tint: tint)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { localError != nil || launchAtLogin.errorMessage != nil },
            set: { visible in
                if !visible {
                    localError = nil
                    launchAtLogin.errorMessage = nil
                }
            }
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a JSON file exported by Prompt Shelf"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingImportURL = url
        showsImportConfirmation = true
    }

    private func performImport() {
        guard let url = pendingImportURL else { return }
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
            pendingImportURL = nil
        }

        do {
            try store.importDocument(from: url)
        } catch {
            localError = error.localizedDescription
        }
    }

    private func exportDocument() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "PromptShelf-Backup.json"
        panel.message = "The export preserves prompt content and the current order"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(to: url)
        } catch {
            localError = error.localizedDescription
        }
    }
}
