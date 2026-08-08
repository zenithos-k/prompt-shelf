import SwiftUI

struct VariableFillView: View {
    let prompt: PromptSnippet
    let onCancel: () -> Void
    let onCopy: (String) -> Void

    @State private var values: [String: String]
    @FocusState private var focusedVariable: String?

    private let variables: [String]

    init(
        prompt: PromptSnippet,
        onCancel: @escaping () -> Void,
        onCopy: @escaping (String) -> Void
    ) {
        self.prompt = prompt
        self.onCancel = onCancel
        self.onCopy = onCopy
        let detected = PromptTemplate.variables(in: prompt.body)
        variables = detected
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: detected.map { ($0, "") }))
    }

    private var renderedPrompt: String {
        PromptTemplate.render(prompt.body, values: values)
    }

    private var missingVariables: [String] {
        variables.filter {
            values[$0, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fieldsSection
                    previewSection
                }
                .padding(16)
            }

            Divider().opacity(0.55)
            actionBar
        }
        .onAppear {
            focusedVariable = variables.first
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .accessibilityLabel("返回")
            }
            .buttonStyle(ShelfIconButtonStyle())
            .keyboardShortcut(.cancelAction)

            VStack(alignment: .leading, spacing: 1) {
                Text(prompt.title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                Text("填写 \(variables.count) 个变量后复制")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("变量", systemImage: "curlybraces")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(variables, id: \.self) { variable in
                VStack(alignment: .leading, spacing: 6) {
                    Text(variable)
                        .font(.system(size: 11.5, weight: .medium))

                    TextField("输入 \(variable)", text: binding(for: variable))
                        .textFieldStyle(.plain)
                        .focused($focusedVariable, equals: variable)
                        .padding(.horizontal, 11)
                        .frame(height: 36)
                        .shelfCard(cornerRadius: 9, tint: ShelfColors.azure)
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("实时预览", systemImage: "eye")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !missingVariables.isEmpty {
                    Text("还需填写 \(missingVariables.count) 项")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                }
            }

            Text(renderedPrompt)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(12)
                .shelfCard(cornerRadius: 10, tint: ShelfColors.violet)
        }
    }

    private var actionBar: some View {
        HStack {
            Text("未填写的变量不会被替换")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("取消", action: onCancel)
            Button("复制") {
                onCopy(renderedPrompt)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!missingVariables.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(.ultraThinMaterial)
    }

    private func binding(for variable: String) -> Binding<String> {
        Binding(
            get: { values[variable, default: ""] },
            set: { values[variable] = $0 }
        )
    }
}
