import Foundation
import Observation
import EditSmithCore

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

    @discardableResult
    func testAndEnableCurrent() -> Bool {
        guard let selectedIndex, recipes[selectedIndex].kind == .javascript else { return false }
        guard !recipes[selectedIndex].testCases.isEmpty else {
            errorMessage = "Add at least one test case before enabling this action in Xcode."
            return false
        }
        runAll()
        guard !testResults.isEmpty, testResults.allSatisfy(\.passed) else {
            errorMessage = "Fix the failing test cases before enabling this action in Xcode."
            return false
        }
        recipes[selectedIndex].isEnabled = true
        save()
        return true
    }
}
