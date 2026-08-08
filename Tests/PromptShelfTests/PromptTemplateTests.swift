import Testing
@testable import PromptShelf

@Suite("Prompt template")
struct PromptTemplateTests {
    @Test("Variables preserve first-seen order and remove duplicates")
    func variablesPreserveFirstSeenOrderAndRemoveDuplicates() {
        let source = "Review {{ file }} for {{topic}}. Then revisit {{file}} and {{中文变量}}."

        #expect(
            PromptTemplate.variables(in: source)
                == ["file", "topic", "中文变量"]
        )
    }

    @Test("Rendering replaces repeated variables and keeps unresolved tokens")
    func renderReplacesRepeatedVariablesAndKeepsUnresolvedTokens() {
        let source = "Use {{language}}. {{ language }} should handle {{missing}}."

        #expect(
            PromptTemplate.render(source, values: ["language": "Swift"])
                == "Use Swift. Swift should handle {{missing}}."
        )
    }

    @Test("Malformed and multiline variables are ignored")
    func malformedOrMultilineVariablesAreIgnored() {
        let source = "{{}} {{open} {{line\nbreak}} {{ valid }}"
        #expect(PromptTemplate.variables(in: source) == ["valid"])
    }
}
