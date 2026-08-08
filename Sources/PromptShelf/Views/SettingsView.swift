import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: PromptStore
    @Environment(\.colorScheme) private var colorScheme
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
            .background { ShelfChromeBackground() }
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
        .background { ShelfChromeBackground() }
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
            .labelsHidden()

            Label("System follows your current macOS appearance automatically.", systemImage: "sparkles")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private var behaviorSection: some View {
        settingsCard(title: "Behavior", systemImage: "switch.2", tint: ShelfColors.azure) {
            settingToggleRow(
                title: "Launch at Login",
                description: "Keep Prompt Shelf ready after you sign in.",
                systemImage: "power",
                isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                )
            )

            if launchAtLogin.needsApproval {
                Text("Approval is required in System Settings → General → Login Items.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
            }

            Divider()

            settingToggleRow(
                title: "Close After Copying",
                description: "Return to your work as soon as copying succeeds.",
                systemImage: "rectangle.portrait.and.arrow.right",
                isOn: $closeAfterCopy
            )
        }
    }

    private var dataSection: some View {
        settingsCard(title: "Data", systemImage: "externaldrive", tint: ShelfColors.violet) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local JSON")
                        .font(.system(size: 12, weight: .semibold))
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
                .buttonStyle(.bordered)
            }

            Divider()

            HStack {
                Button("Import…", action: chooseImportFile)
                    .buttonStyle(.bordered)
                Button("Export…", action: exportDocument)
                    .buttonStyle(.bordered)
                Spacer()
                Label("Stored only on this Mac", systemImage: "lock")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        settingsCard(title: "About", systemImage: "info.circle", tint: ShelfColors.indigo) {
            HStack(spacing: 10) {
                AppMarkView(size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Prompt Shelf")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("Fast prompts, right in the menu bar")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Version \(appVersion)")
                    .foregroundStyle(.secondary)
            }

            Text("Native SwiftUI, automatic {{variable}} detection, gesture-based ordering, and readable local backups.")
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
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(colorScheme == .light ? tint : Color.white)
                    .frame(width: 25, height: 25)
                    .background(tint.opacity(colorScheme == .light ? 0.11 : 0.28), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .shelfCard(cornerRadius: 14, tint: tint, tintOpacity: colorScheme == .light ? 0.035 : nil)
    }

    private func settingToggleRow(
        title: String,
        description: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ShelfColors.azure)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                Text(description)
                    .font(.system(size: 9.75))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
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
