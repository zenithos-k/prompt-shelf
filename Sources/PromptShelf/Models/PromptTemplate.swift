import Foundation

enum PromptTemplate {
    private static let variableExpression = try! NSRegularExpression(
        pattern: #"\{\{\s*([^{}\n]+?)\s*\}\}"#
    )

    static func variables(in template: String) -> [String] {
        let source = template as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        var seen = Set<String>()
        var result: [String] = []

        for match in variableExpression.matches(in: template, range: fullRange) {
            guard match.numberOfRanges > 1 else { continue }
            let name = source.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            result.append(name)
        }

        return result
    }

    static func render(_ template: String, values: [String: String]) -> String {
        let source = template as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let matches = variableExpression.matches(in: template, range: fullRange)
        var result = template

        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let swiftRange = Range(match.range, in: result) else {
                continue
            }

            let name = source.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value = values[name], !value.isEmpty else { continue }
            result.replaceSubrange(swiftRange, with: value)
        }

        return result
    }
}
