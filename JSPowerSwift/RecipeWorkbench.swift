import SwiftUI
import Observation
import JSPowerCore

@MainActor @Observable
final class RecipeLibrary {
    enum ResultMode: String, CaseIterable, Identifiable {
        case output = "Output"
        case diff = "Diff"
        case console = "Console"
        var id: Self { self }
    }

    var recipes: [Recipe]
    var selection: Recipe.ID?
    var testSelection: RecipeTestCase.ID?
    var execution: ExecutionResult?
    var testResults: [RecipeTestResult] = []
    var resultMode = ResultMode.output
    var errorMessage: String?
    private let store = RecipeStore()

    init() {
        recipes = store.load()
        selection = recipes.first?.id
        synchronizeTestSelection()
    }

    var selectedIndex: Int? { selection.flatMap { id in recipes.firstIndex { $0.id == id } } }

    var selectedTestIndex: Int? {
        guard let selectedIndex, let testSelection else { return nil }
        return recipes[selectedIndex].testCases.firstIndex { $0.id == testSelection }
    }

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    func synchronizeTestSelection() {
        guard let selectedIndex else { testSelection = nil; return }
        if !recipes[selectedIndex].testCases.contains(where: { $0.id == testSelection }) {
            testSelection = recipes[selectedIndex].testCases.first?.id
        }
        execution = nil
        testResults = []
    }

    func addRecipe() {
        let test = RecipeTestCase(expectedOutput: "let greeting = \"hello\";")
        let recipe = Recipe(
            name: "New Recipe",
            summary: "Local JavaScript transformation",
            kind: .javascript,
            source: "function transform(input) {\n  console.log('Running recipe', { length: input.length });\n  return input;\n}",
            testCases: [test]
        )
        recipes.append(recipe)
        selection = recipe.id
        testSelection = test.id
        save()
    }

    func deleteSelection() {
        guard let selectedIndex, recipes[selectedIndex].kind == .javascript else { return }
        recipes.remove(at: selectedIndex)
        selection = recipes.first?.id
        synchronizeTestSelection()
        save()
    }

    func addTest() {
        guard let selectedIndex else { return }
        let test = RecipeTestCase(name: "Test \(recipes[selectedIndex].testCases.count + 1)")
        recipes[selectedIndex].testCases.append(test)
        testSelection = test.id
        execution = nil
        save()
    }

    func selectTest(_ id: RecipeTestCase.ID) {
        testSelection = id
        execution = nil
        testResults = []
    }

    func deleteTest() {
        guard let selectedIndex, let selectedTestIndex else { return }
        recipes[selectedIndex].testCases.remove(at: selectedTestIndex)
        testSelection = recipes[selectedIndex].testCases.first?.id
        execution = nil
        save()
    }

    func addSelectionRange() {
        guard let selectedIndex, let selectedTestIndex else { return }
        recipes[selectedIndex].testCases[selectedTestIndex].selections.append(
            TextRange(start: .init(line: 0, column: 0), end: .init(line: 0, column: 0))
        )
    }

    func removeSelectionRange(at offsets: IndexSet) {
        guard let selectedIndex, let selectedTestIndex else { return }
        recipes[selectedIndex].testCases[selectedTestIndex].selections.remove(atOffsets: offsets)
    }

    func save() {
        do { try store.save(recipes); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func runCurrent() {
        guard let selectedIndex, let selectedTestIndex else { return }
        let recipe = recipes[selectedIndex]
        let test = recipe.testCases[selectedTestIndex]
        execution = RecipeRunner().execute(
            ExecutionRequest(text: test.input, selections: test.selections),
            recipe: recipe
        )
        resultMode = execution?.diagnostic == nil ? .output : .console
    }

    func runAll() {
        guard let selectedIndex else { return }
        testResults = RecipeTestRunner().runAll(recipe: recipes[selectedIndex])
        if let selectedTestIndex {
            execution = testResults.first { $0.id == recipes[selectedIndex].testCases[selectedTestIndex].id }?.execution
        }
        resultMode = .console
    }

    func updateSnapshot() {
        guard let selectedIndex, let selectedTestIndex, let execution else { return }
        recipes[selectedIndex].testCases[selectedTestIndex].expectedOutput = execution.outputText
        recipes[selectedIndex].testCases[selectedTestIndex].expectedError = execution.diagnostic?.message
        save()
        runAll()
    }
}

struct RecipeWorkbench: View {
    @State private var library = RecipeLibrary()

    var body: some View {
        @Bindable var library = library
        NavigationSplitView {
            List(library.recipes, selection: $library.selection) { recipe in
                VStack(alignment: .leading, spacing: 3) {
                    Label(recipe.name, systemImage: recipe.kind == .builtin ? "wand.and.stars" : "curlybraces")
                    Text(recipe.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                .tag(recipe.id)
            }
            .navigationTitle("Recipes")
            .navigationSplitViewColumnWidth(min: 230, ideal: 280)
            .toolbar {
                Button("Add Recipe", systemImage: "plus", action: library.addRecipe)
                Button("Delete Recipe", systemImage: "trash", role: .destructive, action: library.deleteSelection)
                    .disabled(library.selectedIndex.map { library.recipes[$0].kind == .builtin } ?? true)
            }
        } detail: {
            if let index = library.selectedIndex {
                RecipeEditor(recipe: $library.recipes[index], library: library)
                    .id(library.recipes[index].id)
            } else {
                ContentUnavailableView("Select a recipe", systemImage: "curlybraces")
            }
        }
        .onChange(of: library.selection) { library.synchronizeTestSelection() }
        .alert("Recipe Error", isPresented: $library.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: { Text(library.errorMessage ?? "") }
    }
}

private struct RecipeEditor: View {
    @Binding var recipe: Recipe
    let library: RecipeLibrary

    var body: some View {
        @Bindable var library = library
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $recipe.name)
                TextField("Description", text: $recipe.summary)
                Toggle("Enabled in Xcode", isOn: $recipe.isEnabled)
            }
            .formStyle(.grouped)
            .frame(height: 132)

            if let testIndex = library.selectedTestIndex {
                VSplitView {
                    HSplitView {
                        EditorPane(
                            title: recipe.kind == .builtin ? "Built-in action" : "JavaScript",
                            text: $recipe.source,
                            editable: recipe.kind == .javascript
                        )
                        TestFixtureEditor(test: $recipe.testCases[testIndex], library: library)
                        EditorPane(title: "Expected Output", text: $recipe.testCases[testIndex].expectedOutput, editable: true)
                    }
                    ResultInspector(
                        input: recipe.testCases[testIndex].input,
                        source: recipe.source,
                        execution: library.execution,
                        results: library.testResults,
                        mode: $library.resultMode
                    )
                    .frame(minHeight: 220, idealHeight: 280)
                }
            } else {
                ContentUnavailableView {
                    Label("No test cases", systemImage: "checklist")
                } description: {
                    Text("Add a test case to run this recipe without loading it into Xcode.")
                } actions: {
                    Button("Add Test Case", action: library.addTest)
                }
            }
        }
        .navigationTitle(recipe.name)
        .toolbar {
            Button("Run Test", systemImage: "play.fill", action: library.runCurrent)
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(library.selectedTestIndex == nil)
            Button("Run All", systemImage: "checkmark.circle", action: library.runAll)
                .disabled(recipe.testCases.isEmpty)
            Button("Update Snapshot", systemImage: "arrow.triangle.2.circlepath", action: library.updateSnapshot)
                .disabled(library.execution == nil)
            Button("Save", systemImage: "square.and.arrow.down", action: library.save)
                .keyboardShortcut("s", modifiers: [.command])
        }
    }
}

private struct TestFixtureEditor: View {
    @Binding var test: RecipeTestCase
    let library: RecipeLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Test name", text: $test.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                Spacer()
                Menu("Test Cases", systemImage: "checklist") {
                    ForEach(library.recipes[library.selectedIndex!].testCases) { item in
                        Button(item.name) { library.selectTest(item.id) }
                    }
                    Divider()
                    Button("Add Test", systemImage: "plus", action: library.addTest)
                    Button("Delete Test", systemImage: "trash", role: .destructive, action: library.deleteTest)
                }
                .labelStyle(.iconOnly)
            }
            .padding(.horizontal)

            TextEditor(text: $test.input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary, in: .rect(cornerRadius: 8))
                .padding(.horizontal)

            TextField(
                "Expected error (optional)",
                text: Binding(
                    get: { test.expectedError ?? "" },
                    set: { test.expectedError = $0.isEmpty ? nil : $0 }
                )
            )
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)

            HStack {
                Text(test.selections.isEmpty ? "Whole buffer" : "Selections")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("Add Selection", systemImage: "plus", action: library.addSelectionRange)
                    .labelStyle(.iconOnly)
            }
            .padding(.horizontal)

            List {
                ForEach($test.selections) { $selection in
                    SelectionEditor(selection: $selection)
                }
                .onDelete(perform: library.removeSelectionRange)
            }
            .frame(minHeight: 76, maxHeight: 110)
        }
        .frame(minWidth: 300)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Xcode buffer test fixture")
    }
}

private struct SelectionEditor: View {
    @Binding var selection: JSPowerCore.TextRange

    var body: some View {
        HStack(spacing: 5) {
            Text("L")
            TextField("Start line", value: $selection.start.line, format: .number).frame(width: 34)
            Text(":")
            TextField("Start column", value: $selection.start.column, format: .number).frame(width: 34)
            Text("→")
            TextField("End line", value: $selection.end.line, format: .number).frame(width: 34)
            Text(":")
            TextField("End column", value: $selection.end.column, format: .number).frame(width: 34)
        }
        .font(.system(.caption, design: .monospaced))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selection range")
    }
}

private struct EditorPane: View {
    let title: String
    @Binding var text: String
    let editable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).padding(.horizontal)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .disabled(!editable)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary, in: .rect(cornerRadius: 8))
                .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 260)
    }
}

private struct ResultInspector: View {
    let input: String
    let source: String
    let execution: ExecutionResult?
    let results: [RecipeTestResult]
    @Binding var mode: RecipeLibrary.ResultMode

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Result", selection: $mode) {
                    ForEach(RecipeLibrary.ResultMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
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

private struct DiffView: View {
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

struct ExtensionHelpView: View {
    var body: some View {
        Form {
            Section("Enable JSPower") {
                Text("Open System Settings → Privacy & Security → Extensions → Xcode Source Editor, then enable JSPower.")
                Button("Open Extensions Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                }
            }
            Section("Privacy") {
                Text("Recipes, fixtures, logs, and sample text stay on this Mac. JavaScript recipes receive only the text Xcode passes to the extension.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 320)
    }
}
