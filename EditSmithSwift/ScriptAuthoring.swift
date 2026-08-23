import SwiftUI

struct ScriptAPIItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let signature: String
    let summary: String
    let snippet: String
}

enum ScriptAPICatalog {
    static let items: [ScriptAPIItem] = [
        .init(id: "builtin", title: "Built-in composition", signature: "EditSmith.runBuiltin(identifier, input, parameters)", summary: "Compose any local built-in capability inside a custom script.", snippet: "return EditSmith.runBuiltin(\"trim-lines\", input, {});"),
        .init(
            id: "transform",
            title: "Transform entry point",
            signature: "function transform(input): string",
            summary: "Required entry point. Return the text that should replace the Xcode buffer or selection.",
            snippet: "function transform(input) {\n  return input;\n}"
        ),
        .init(
            id: "environment",
            title: "Xcode environment",
            signature: "environment.fileName · fileType · indentationWidth",
            summary: "Read-only metadata supplied by Xcode. Scripts cannot access files, processes, or the network.",
            snippet: "const { fileName, fileType, indentationWidth } = environment;"
        ),
        .init(
            id: "console",
            title: "Console",
            signature: "console.log/info/warn/error(...values)",
            summary: "Write structured debug output to the test result console.",
            snippet: "console.log('Transforming', { file: environment.fileName, length: input.length });"
        ),
        .init(
            id: "selection",
            title: "Selection-aware input",
            signature: "input: string",
            summary: "When Xcode supplies selections, transform is called once for each selection in document order.",
            snippet: "return input.split('\\n').map(line => line.trimEnd()).join('\\n');"
        ),
    ]
}

struct ScriptIssue: Identifiable, Equatable, Sendable {
    enum Severity: Sendable { case error, warning }
    let id: String
    let severity: Severity
    let message: String
    let line: Int?
}

enum ScriptLinter {
    static func inspect(_ source: String) -> [ScriptIssue] {
        var issues: [ScriptIssue] = []
        if !source.contains("function transform") && !source.contains("const transform") && !source.contains("let transform") {
            issues.append(.init(id: "entry", severity: .error, message: "Define transform(input) as the script entry point.", line: nil))
        }
        if source.utf8.count > 256 * 1_024 {
            issues.append(.init(id: "size", severity: .error, message: "Script exceeds the 256 KB execution limit.", line: nil))
        }
        let discouraged = ["eval(": "Dynamic code evaluation is not available.", "fetch(": "Network access is not available.", "require(": "Modules cannot be imported."]
        for (token, message) in discouraged where source.contains(token) {
            let line = source[..<source.range(of: token)!.lowerBound].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            issues.append(.init(id: token, severity: .warning, message: message, line: line))
        }
        issues.append(contentsOf: delimiterIssues(in: source))
        return issues
    }

    private static func delimiterIssues(in source: String) -> [ScriptIssue] {
        var stack: [(Character, Int)] = []
        var quote: Character?
        var escaped = false
        var line = 1
        let pairs: [Character: Character] = [")": "(", "]": "[", "}": "{"]

        for character in source {
            defer { if character == "\n" { line += 1 } }
            if escaped { escaped = false; continue }
            if character == "\\", quote != nil { escaped = true; continue }
            if let activeQuote = quote {
                if character == activeQuote { quote = nil }
                continue
            }
            if character == "\"" || character == "'" || character == "`" { quote = character; continue }
            if "([{".contains(character) { stack.append((character, line)); continue }
            guard let expected = pairs[character] else { continue }
            guard stack.last?.0 == expected else {
                return [.init(id: "delimiter-\(line)", severity: .error, message: "Unexpected closing delimiter \(character).", line: line)]
            }
            stack.removeLast()
        }
        if let quote { return [.init(id: "quote", severity: .error, message: "Unclosed \(quote) string.", line: line)] }
        if let unclosed = stack.last { return [.init(id: "delimiter", severity: .error, message: "Unclosed \(unclosed.0) delimiter.", line: unclosed.1)] }
        return []
    }
}

struct ScriptReferenceView: View {
    @Binding var source: String

    var body: some View {
        List(ScriptAPICatalog.items) { item in
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.title).font(.headline)
                    Spacer()
                    Button("Insert", systemImage: "plus") { insert(item.snippet) }
                        .labelStyle(.iconOnly)
                        .help("Insert snippet at the end of the script")
                }
                Text(item.signature).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                Text(item.summary).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 3)
        }
        .listStyle(.inset)
        .safeAreaInset(edge: .bottom) {
            Text("Local only · 256 KB script · 5 MB input/output · 1 second per run")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
    }

    private func insert(_ snippet: String) {
        if !source.isEmpty && !source.hasSuffix("\n") { source += "\n" }
        source += snippet + "\n"
    }
}

struct ScriptIssuesBar: View {
    let issues: [ScriptIssue]

    var body: some View {
        HStack(spacing: 12) {
            if issues.isEmpty {
                Label("No quick-check issues", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                ForEach(issues.prefix(2)) { issue in
                    Label(
                        (issue.line.map { "Line \($0): " } ?? "") + issue.message,
                        systemImage: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(issue.severity == .error ? .red : .orange)
                    .lineLimit(1)
                }
                if issues.count > 2 { Text("+\(issues.count - 2) more").foregroundStyle(.secondary) }
            }
            Spacer()
            Text("Quick check · Run tests for authoritative results").foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .frame(height: 28)
    }
}
