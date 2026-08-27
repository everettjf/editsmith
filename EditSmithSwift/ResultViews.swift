import SwiftUI
import AppKit
import EditSmithCore

struct ResultInspector: View {
    let input: String
    let source: String
    let execution: ExecutionResult?
    let results: [RecipeTestResult]
    @Binding var mode: RecipeLibrary.ResultMode
    let isRunning: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Result", systemImage: "terminal")
                    .font(.headline)
                Picker("Result", selection: $mode) {
                    ForEach(RecipeLibrary.ResultMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 210, idealWidth: 260, maxWidth: 320)
                .layoutPriority(1)
                Spacer()
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Running…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let execution {
                    StatusBadge(
                        title: execution.succeeded ? "Succeeded" : "Failed",
                        systemImage: execution.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill",
                        color: execution.succeeded ? .green : .red
                    )
                    Text("\(execution.duration * 1_000, format: .number.precision(.fractionLength(1))) ms")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }

            if let diagnostic = execution?.diagnostic {
                DiagnosticBanner(diagnostic: diagnostic, source: source)
            }

            Group {
                switch mode {
                case .output:
                    if let execution {
                        MonospacedResultText(text: execution.outputText)
                    } else {
                        ContentUnavailableView("No Output Yet", systemImage: "play.circle", description: Text("Run the selected test to inspect its transformed output."))
                    }
                case .diff:
                    DiffView(before: input, after: execution?.outputText ?? input)
                case .console:
                    ConsoleView(logs: execution?.logs ?? [], results: results)
                }
            }
        }
    }

}

private struct StatusBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: .capsule)
    }
}

private struct DiagnosticBanner: View {
    let diagnostic: ExecutionDiagnostic
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(diagnostic.message).font(.headline)
                Spacer()
                if let line = diagnostic.line {
                    Text("Line \(line)" + (diagnostic.column.map { ", Column \($0)" } ?? ""))
                        .font(.system(.caption, design: .monospaced))
                }
            }
            if let stack = diagnostic.stack, !stack.isEmpty {
                Text(stack).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            }
            if let excerpt {
                Text(excerpt)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .foregroundStyle(.red)
        .background(.red.opacity(0.08))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("JavaScript error")
    }

    private var excerpt: String? {
        guard let line = diagnostic.line, line > 0 else { return nil }
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.indices.contains(line - 1) else { return nil }
        let sourceLine = String(lines[line - 1])
        guard let column = diagnostic.column, column > 0 else { return "\(line) │ \(sourceLine)" }
        return "\(line) │ \(sourceLine)\n" + String(repeating: " ", count: String(line).count + column + 2) + "^"
    }
}

private struct MonospacedResultText: View {
    let text: String
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()
        }
    }
}

struct DiffView: View {
    let before: String
    let after: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                diffHeader("Before", systemImage: "minus")
                Divider()
                diffHeader("After", systemImage: "plus")
            }
            Divider()

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0) {
                    ForEach(LineDiff.compute(before: before, after: after)) { row in
                        HStack(spacing: 0) {
                            DiffCell(number: row.beforeNumber, text: row.before, kind: row.kind, side: .before)
                            Divider()
                            DiffCell(number: row.afterNumber, text: row.after, kind: row.kind, side: .after)
                        }
                    }
                }
            }
            .background(.background)
        }
    }

    private func diffHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .frame(height: 28)
    }
}

struct LineDiff {
    enum Kind: Equatable { case unchanged, removed, added, modified }

    struct Row: Identifiable {
        let id: Int
        let beforeNumber: Int?
        let afterNumber: Int?
        let before: String?
        let after: String?
        let kind: Kind
    }

    static func compute(before: String, after: String) -> [Row] {
        let old = before.components(separatedBy: "\n")
        let new = after.components(separatedBy: "\n")
        guard old.count * new.count <= 1_000_000 else { return positional(old: old, new: new) }

        var table = Array(repeating: Array(repeating: 0, count: new.count + 1), count: old.count + 1)
        if !old.isEmpty, !new.isEmpty {
            for i in stride(from: old.count - 1, through: 0, by: -1) {
                for j in stride(from: new.count - 1, through: 0, by: -1) {
                    table[i][j] = old[i] == new[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
                }
            }
        }

        var raw: [(Int?, Int?, String?, String?, Kind)] = []
        var i = 0, j = 0
        while i < old.count || j < new.count {
            if i < old.count, j < new.count, old[i] == new[j] {
                raw.append((i + 1, j + 1, old[i], new[j], .unchanged)); i += 1; j += 1
            } else if i < old.count, j < new.count, table[i + 1][j] == table[i][j + 1] {
                raw.append((i + 1, j + 1, old[i], new[j], .modified)); i += 1; j += 1
            } else if j < new.count, i == old.count || table[i][j + 1] > table[i + 1][j] {
                raw.append((nil, j + 1, nil, new[j], .added)); j += 1
            } else {
                raw.append((i + 1, nil, old[i], nil, .removed)); i += 1
            }
        }
        return raw.enumerated().map { Row(id: $0.offset, beforeNumber: $0.element.0, afterNumber: $0.element.1, before: $0.element.2, after: $0.element.3, kind: $0.element.4) }
    }

    private static func positional(old: [String], new: [String]) -> [Row] {
        (0..<max(old.count, new.count)).map { index in
            let before = old.indices.contains(index) ? old[index] : nil
            let after = new.indices.contains(index) ? new[index] : nil
            let kind: Kind = before == after ? .unchanged : (before == nil ? .added : (after == nil ? .removed : .modified))
            return Row(id: index, beforeNumber: before == nil ? nil : index + 1, afterNumber: after == nil ? nil : index + 1, before: before, after: after, kind: kind)
        }
    }
}

private struct DiffCell: View {
    enum Side: Equatable { case before, after }
    let number: Int?
    let text: String?
    let kind: LineDiff.Kind
    let side: Side

    var body: some View {
        HStack(spacing: 0) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.tertiary)
                .frame(width: 42, alignment: .trailing)
                .padding(.trailing, 8)
            Text(prefix)
                .foregroundStyle(accent)
                .frame(width: 18)
            Text(text ?? " ")
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 10)
        }
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 24)
        .background(background)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var prefix: String {
        switch (kind, side) { case (.added, .after): "+"; case (.removed, .before): "−"; case (.modified, .before): "−"; case (.modified, .after): "+"; default: " " }
    }
    private var accent: Color { side == .before ? .red : .green }
    private var background: Color {
        guard kind != .unchanged, text != nil else { return .clear }
        return accent.opacity(kind == .modified ? 0.10 : 0.07)
    }
    private var accessibilityDescription: String {
        let action = kind == .unchanged ? "Unchanged" : (side == .before ? "Removed" : "Added")
        return "\(action), line \(number ?? 0): \(text ?? "blank")"
    }
}

private struct ConsoleView: View {
    let logs: [ExecutionLog]
    let results: [RecipeTestResult]
    @State private var level = ConsoleLevel.all
    @State private var isCleared = false

    private enum ConsoleLevel: String, CaseIterable, Identifiable {
        case all = "All", info = "Info", warnings = "Warnings", errors = "Errors"
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Log level", selection: $level) {
                    ForEach(ConsoleLevel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(consoleText, forType: .string)
                }
                    .labelStyle(.iconOnly)
                    .help("Copy visible console output")
                Button("Clear", systemImage: "trash") { isCleared = true }
                    .labelStyle(.iconOnly)
                    .help("Clear console from this view")
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(.bar)

            List {
            if !results.isEmpty {
                Section("Test Run") {
                    ForEach(results) { result in
                        Label(result.name, systemImage: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.passed ? .green : .red)
                    }
                }
            }
            Section("Console") {
                if visibleLogs.isEmpty {
                    ContentUnavailableView("No Console Output", systemImage: "terminal", description: Text(isCleared ? "Run the test again to restore its logs." : "No messages match the current filter."))
                } else {
                    ForEach(visibleLogs) { log in
                        HStack(alignment: .firstTextBaseline) {
                            Text(log.level.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(color(for: log.level))
                                .frame(width: 48, alignment: .leading)
                            Text(log.message).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Spacer()
                            Text(log.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        }
        .onChange(of: logs) { isCleared = false }
    }

    private var visibleLogs: [ExecutionLog] {
        guard !isCleared else { return [] }
        return logs.filter { log in
            switch level {
            case .all: true
            case .info: log.level == .log || log.level == .info
            case .warnings: log.level == .warn
            case .errors: log.level == .error
            }
        }
    }

    private var consoleText: String {
        visibleLogs.map { "[\($0.level.rawValue.uppercased())] \($0.message)" }.joined(separator: "\n")
    }

    private func color(for level: ExecutionLog.Level) -> Color {
        switch level { case .log, .info: .secondary; case .warn: .orange; case .error: .red }
    }
}

#Preview("Line Diff – Added, Removed, Modified") {
    DiffView(
        before: "struct User {\n    let name: String\n    let legacyID: Int\n}",
        after: "struct User: Sendable {\n    let displayName: String\n    let isActive: Bool\n}"
    )
    .frame(width: 820, height: 360)
}

#Preview("Console – Mixed Levels") {
    ConsoleView(
        logs: [
            ExecutionLog(level: .info, message: "Running fixture: Multiple selections"),
            ExecutionLog(level: .warn, message: "Input contains two empty lines"),
            ExecutionLog(level: .error, message: "Example diagnostic for visual review"),
        ],
        results: [
            RecipeTestResult(
                testCase: RecipeTestCase(name: "Whole buffer", input: "hello", expectedOutput: "HELLO"),
                execution: ExecutionResult(outputText: "HELLO")
            ),
            RecipeTestResult(
                testCase: RecipeTestCase(name: "Selection", input: "world", expectedOutput: "WORLD"),
                execution: ExecutionResult(outputText: "world")
            ),
        ]
    )
    .frame(width: 720, height: 360)
}

#Preview("Result – Empty State") {
    ResultInspector(
        input: "let message = \"Hello\"",
        source: "function transform(input) { return input; }",
        execution: nil,
        results: [],
        mode: .constant(.output),
        isRunning: false
    )
    .frame(width: 720, height: 360)
}
