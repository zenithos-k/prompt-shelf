import SwiftUI

struct PromptEditorView: View {
    let prompt: PromptSnippet?
    let onCancel: () -> Void
    let onSave: (_ title: String, _ body: String) -> Void
    let onDelete: (() -> Void)?

    @State private var title: String
    @State private var bodyText: String
    @State private var showsDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case body
    }

    init(
        prompt: PromptSnippet?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ title: String, _ body: String) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.prompt = prompt
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: prompt?.title ?? "")
        _bodyText = State(initialValue: prompt?.body ?? "")
    }

    private var variables: [String] {
        PromptTemplate.variables(in: bodyText)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleSection
                    bodySection
                    detectedVariablesSection
                }
                .padding(16)
            }

            Divider().opacity(0.55)
            actionBar
        }
        .onAppear {
            DispatchQueue.main.async {
                focusedField = prompt == nil ? .title : .body
            }
        }
        .alert(prompt?.title ?? title, isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .accessibilityLabel("Back")
            }
            .buttonStyle(ShelfIconButtonStyle())
            .keyboardShortcut(.cancelAction)

            VStack(alignment: .leading, spacing: 1) {
                Text(prompt == nil ? "New Prompt" : "Edit Prompt")
                    .font(.system(size: 15, weight: .bold))
                Text("{{variables}} are detected automatically")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel("Name")
            TextField("For example: Review current changes", text: $title)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .title)
                .padding(.horizontal, 11)
                .frame(height: 36)
                .shelfCard(cornerRadius: 9, tint: ShelfColors.azure)
        }
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                fieldLabel("Prompt content")
                Spacer()
                Text("\(bodyText.count) characters")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            TextEditor(text: $bodyText)
                .font(.system(size: 12.5, design: .monospaced))
                .focused($focusedField, equals: .body)
                .scrollContentBackground(.hidden)
                .padding(7)
                .frame(minHeight: 220)
                .shelfCard(cornerRadius: 10, tint: ShelfColors.indigo)
        }
    }

    private var detectedVariablesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                fieldLabel("Detected variables")
                Spacer()
                Text("\(variables.count)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            if variables.isEmpty {
                Label("Type {{variable_name}} in the content. Prompt Shelf will ask for its value before copying.", systemImage: "sparkles")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            } else {
                VariableChips(variables: variables)
            }
        }
        .padding(12)
        .shelfCard(cornerRadius: 10, tint: ShelfColors.violet)
    }

    private var actionBar: some View {
        HStack {
            if onDelete != nil {
                Button("Delete", role: .destructive) {
                    showsDeleteConfirmation = true
                }
            }

            Spacer()

            Button("Cancel", action: onCancel)
            Button("Save") {
                onSave(title, bodyText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(.ultraThinMaterial)
    }

    private func fieldLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}
