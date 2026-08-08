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
                Button("退出 Prompt Shelf", role: .destructive) {
                    store.flush()
                    NSApp.terminate(nil)
                }
                Spacer()
                Button("完成", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(.ultraThinMaterial)
        }
        .onAppear { launchAtLogin.refresh() }
        .alert("无法完成操作", isPresented: errorBinding) {
            Button("好", role: .cancel) {
                localError = nil
                launchAtLogin.errorMessage = nil
            }
        } message: {
            Text(localError ?? launchAtLogin.errorMessage ?? "未知错误")
        }
        .confirmationDialog(
            "导入会替换当前 Prompt",
            isPresented: $showsImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("导入并替换", role: .destructive) {
                performImport()
            }
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("建议先导出一份备份。导入成功后会保留文件中的排序。")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onDone) {
                Image(systemName: "chevron.left")
                    .accessibilityLabel("返回")
            }
            .buttonStyle(ShelfIconButtonStyle())
            .keyboardShortcut(.cancelAction)

            VStack(alignment: .leading, spacing: 1) {
                Text("设置")
                    .font(.system(size: 15, weight: .bold))
                Text("外观、行为与本地数据")
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
            title: "外观",
            systemImage: "circle.lefthalf.filled",
            tint: ShelfColors.indigo
        ) {
            Picker("显示模式", selection: appearanceBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.symbolName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("“自动”会跟随 macOS 当前的浅色或深色外观。")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private var behaviorSection: some View {
        settingsCard(title: "行为", systemImage: "switch.2", tint: ShelfColors.azure) {
            Toggle("登录时启动", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            .toggleStyle(.switch)

            if launchAtLogin.needsApproval {
                Text("需要在“系统设置 → 通用 → 登录项”中批准。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.orange)
            }

            Divider()

            Toggle("复制后关闭窗口", isOn: $closeAfterCopy)
                .toggleStyle(.switch)
        }
    }

    private var dataSection: some View {
        settingsCard(title: "数据", systemImage: "externaldrive", tint: ShelfColors.violet) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地 JSON")
                        .font(.system(size: 12, weight: .medium))
                    Text(store.databaseURL.path)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                Spacer()
                Button("在 Finder 中显示") {
                    store.flush()
                    NSWorkspace.shared.activateFileViewerSelecting([store.databaseURL])
                }
            }

            Divider()

            HStack {
                Button("导入…", action: chooseImportFile)
                Button("导出…", action: exportDocument)
                Spacer()
                Label("仅保存在本机", systemImage: "lock")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        settingsCard(title: "关于", systemImage: "info.circle", tint: ShelfColors.indigo) {
            HStack {
                Text("Prompt Shelf")
                Spacer()
                Text("版本 \(appVersion)")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11.5))

            Text("原生 macOS 菜单栏 Prompt 管理器。支持自动变量识别、拖拽排序与本地备份。")
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "选择由 Prompt Shelf 导出的 JSON 文件"

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
        panel.message = "导出会保留 Prompt 内容和当前顺序"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(to: url)
        } catch {
            localError = error.localizedDescription
        }
    }
}
