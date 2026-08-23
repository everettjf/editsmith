import SwiftUI
import Observation
import UniformTypeIdentifiers
import EditSmithCore
#if canImport(FoundationModels)
import FoundationModels
#endif

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
    private let store: RecipeStore

    init(store: RecipeStore = RecipeStore()) {
        self.store = store
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

    func addTemplate(_ template: Recipe) {
        let recipe = Recipe(name: template.name, summary: template.summary, kind: template.kind, source: template.source, isEnabled: false, version: template.version, applicability: template.applicability, parameters: template.parameters, testCases: template.testCases)
        recipes.append(recipe); selection = recipe.id; testSelection = recipe.testCases.first?.id; save()
    }

    func addGeneratedDraft(name: String, source: String, prompt: String) {
        let test = RecipeTestCase(name: "Review this fixture", input: "sample input", expectedOutput: "sample input")
        let recipe = Recipe(
            name: name,
            summary: "On-device draft: \(prompt)",
            kind: .javascript,
            source: source,
            isEnabled: false,
            testCases: [test]
        )
        recipes.append(recipe)
        selection = recipe.id
        testSelection = test.id
        save()
    }

    func duplicateSelection() {
        guard let selectedIndex else { return }
        let original = recipes[selectedIndex]
        let copy = Recipe(
            name: original.name + " Copy",
            summary: original.summary,
            kind: original.kind,
            source: original.source,
            isEnabled: false,
            version: original.version,
            applicability: original.applicability,
            parameters: original.parameters,
            testCases: original.testCases.map {
                RecipeTestCase(
                    name: $0.name,
                    input: $0.input,
                    selections: $0.selections,
                    expectedOutput: $0.expectedOutput,
                    expectedError: $0.expectedError
                )
            }
        )
        recipes.append(copy)
        selection = copy.id
        testSelection = copy.testCases.first?.id
        save()
    }

    func importArchive(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let archive = try RecipeArchive.decode(Data(contentsOf: url))
            let imported = archive.recipes.map { recipe in
                Recipe(
                    name: recipe.name,
                    summary: recipe.summary,
                    kind: recipe.kind,
                    source: recipe.source,
                    isEnabled: false,
                    version: recipe.version,
                    applicability: recipe.applicability,
                    parameters: recipe.parameters,
                    testCases: recipe.testCases
                )
            }
            recipes.append(contentsOf: imported)
            selection = imported.first?.id
            synchronizeTestSelection()
            save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportDocument() -> RecipeArchiveDocument? {
        do {
            let exportable = recipes.filter { $0.kind == .javascript }
            return RecipeArchiveDocument(data: try RecipeArchive(recipes: exportable).encoded())
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
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
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportDocument = RecipeArchiveDocument()
    @State private var isShowingAssistant = false

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
                Menu("Add Recipe", systemImage: "plus") {
                    Button("Blank JavaScript Recipe", action: library.addRecipe)
                    Section("Templates") { ForEach(RecipeTemplates.javascript) { template in Button(template.name) { library.addTemplate(template) } } }
                }
                Button("Delete Recipe", systemImage: "trash", role: .destructive, action: library.deleteSelection)
                    .disabled(library.selectedIndex.map { library.recipes[$0].kind == .builtin } ?? true)
                Menu("Library", systemImage: "ellipsis.circle") {
                    Button("Duplicate Action", systemImage: "plus.square.on.square", action: library.duplicateSelection)
                        .disabled(library.selectedIndex == nil)
                    Divider()
                    Button("Import Actions…", systemImage: "square.and.arrow.down") { isImporting = true }
                    Button("Export User Actions…", systemImage: "square.and.arrow.up") {
                        guard let document = library.exportDocument() else { return }
                        exportDocument = document
                        isExporting = true
                    }
                }
#if canImport(FoundationModels)
                if #available(macOS 26.0, *) {
                    Button("Draft with Apple Intelligence", systemImage: "apple.intelligence") {
                        isShowingAssistant = true
                    }
                }
#endif
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
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): library.importArchive(from: url)
            case .failure(let error): library.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "EditSmith Actions"
        ) { result in
            if case .failure(let error) = result { library.errorMessage = error.localizedDescription }
        }
#if canImport(FoundationModels)
        .sheet(isPresented: $isShowingAssistant) {
            if #available(macOS 26.0, *) {
                ActionDraftAssistantView { name, source, prompt in
                    library.addGeneratedDraft(name: name, source: source, prompt: prompt)
                    isShowingAssistant = false
                }
            }
        }
#endif
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private struct ActionDraftAssistantView: View {
    let onCreate: (String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Generated Action"
    @State private var prompt = ""
    @State private var draft = ""
    @State private var errorMessage: String?
    @State private var isGenerating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Draft an Action").font(.title2.bold())
            Text("Apple Intelligence creates JavaScript locally. The draft stays disabled until you test and enable it.")
                .foregroundStyle(.secondary)
            TextField("Action name", text: $name)
            TextField("Describe the text transformation", text: $prompt, axis: .vertical)
                .lineLimit(3...6)
            if !draft.isEmpty {
                TextEditor(text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
                    .accessibilityLabel("Generated JavaScript draft")
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Generate") { generate() }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                Button("Create Disabled Draft") { onCreate(name, draft, prompt) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 420)
    }

    private func generate() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let model = SystemLanguageModel.default
                guard model.isAvailable else {
                    throw ActionAssistantError.modelUnavailable
                }
                let session = LanguageModelSession(instructions: """
                    You create deterministic, local EditSmith JavaScript actions. Return only JavaScript source defining function transform(input) that returns a string. Do not use network, files, processes, imports, eval, or dynamic code generation.
                    """)
                let response = try await session.respond(to: prompt)
                draft = Self.cleaned(response.content)
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private static func cleaned(_ source: String) -> String {
        source
            .replacingOccurrences(of: "```javascript", with: "")
            .replacingOccurrences(of: "```js", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@available(macOS 26.0, *)
private enum ActionAssistantError: LocalizedError {
    case modelUnavailable
    var errorDescription: String? { "Apple Intelligence is not available on this Mac." }
}
#endif

struct RecipeArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data = Data()

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
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
                Stepper("Action version: \(recipe.version)", value: $recipe.version, in: 1...999)
                Toggle("Requires a selection", isOn: $recipe.applicability.requiresSelection)
                TextField(
                    "File types (comma-separated UTIs; empty means any)",
                    text: Binding(
                        get: { recipe.applicability.fileTypes.joined(separator: ", ") },
                        set: { value in
                            recipe.applicability.fileTypes = value
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                        }
                    )
                )
                if recipe.source == "wrap-selection" {
                    TextField("Prefix", text: parameterBinding("prefix"))
                    TextField("Suffix", text: parameterBinding("suffix"))
                } else if recipe.source == "regex-replace" {
                    TextField("Regex pattern", text: parameterBinding("pattern"))
                    TextField("Replacement", text: parameterBinding("replacement"))
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 190, idealHeight: 240, maxHeight: 280)

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

    private func parameterBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { recipe.parameters[key] ?? "" },
            set: { recipe.parameters[key] = $0 }
        )
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
    @Binding var selection: EditSmithCore.TextRange

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
    @State private var dryRun = ExtensionPreferences().dryRun
    @State private var snapshot = ExtensionPreferences().lastSnapshot
    var body: some View {
        Form {
            Section("Enable EditSmith") {
                Text("Open System Settings → Privacy & Security → Extensions → Xcode Source Editor, then enable EditSmith.")
                Button("Open Extensions Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                }
            }
            Section("Safe Changes") {
                Toggle("Dry Run in Xcode", isOn: $dryRun).onChange(of: dryRun) { _, value in var preferences = ExtensionPreferences(); preferences.dryRun = value }
                Text("Dry Run executes the recipe and saves a before/after preview without modifying the Xcode buffer.")
                if let snapshot {
                    LabeledContent("Last Preview", value: snapshot.recipeName)
                    Text(snapshot.date.formatted(date: .abbreviated, time: .standard)).foregroundStyle(.secondary)
                    DiffView(before: snapshot.before, after: snapshot.after).frame(height: 180)
                    Text("Use Editor → EditSmith → Undo Last EditSmith Change to restore the saved buffer snapshot.").font(.caption)
                }
            }
            Section("Privacy") {
                Text("Recipes, fixtures, logs, and sample text stay on this Mac. JavaScript recipes receive only the text Xcode passes to the extension.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 720, height: 600)
        .onAppear { snapshot = ExtensionPreferences().lastSnapshot }
    }
}
