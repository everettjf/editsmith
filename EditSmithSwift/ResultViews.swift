import SwiftUI
import EditSmithCore

struct ResultInspector: View {
    let input: String
    let source: String
    let execution: ExecutionResult?
    let results: [RecipeTestResult]
    @Binding var mode: RecipeLibrary.ResultMode

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
                .frame(maxWidth: 360)
                Spacer()
                if let execution {
                    Label(execution.succeeded ? "Succeeded" : "Failed", systemImage: execution.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(execution.succeeded ? .green : .red)
                    Text(execution.duration * 1_000, format: .number.precision(.fractionLength(1)))
                    Text("ms")
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
                    MonospacedResultText(text: execution?.outputText ?? "Run a test to see its output.")
                case .diff:
                    DiffView(before: input, after: execution?.outputText ?? input)
                case .console:
                    ConsoleView(logs: execution?.logs ?? [], results: results)
                }
            }
        }
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
        HSplitView {
            diffColumn(title: "Before", prefix: "−", text: before, color: .red)
            diffColumn(title: "After", prefix: "+", text: after, color: .green)
        }
    }

    private func diffColumn(title: String, prefix: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).padding(.horizontal)
            ScrollView {
                Text(text.split(separator: "\n", omittingEmptySubsequences: false).map { "\(prefix) \($0)" }.joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
            }
            .background(color.opacity(0.05))
        }
        .frame(minWidth: 300)
    }
}

private struct ConsoleView: View {
    let logs: [ExecutionLog]
    let results: [RecipeTestResult]

    var body: some View {
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
                if logs.isEmpty {
                    Text("No console output").foregroundStyle(.secondary)
                } else {
                    ForEach(logs) { log in
                        HStack(alignment: .firstTextBaseline) {
                            Text(log.level.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(color(for: log.level))
                                .frame(width: 48, alignment: .leading)
                            Text(log.message).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private func color(for level: ExecutionLog.Level) -> Color {
        switch level { case .log, .info: .secondary; case .warn: .orange; case .error: .red }
    }
}
