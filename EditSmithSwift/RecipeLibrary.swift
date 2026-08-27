import Foundation
import Observation
import EditSmithCore

@MainActor @Observable
final class RecipeLibrary {
    enum Scope: String, CaseIterable, Identifiable {
        case featured = "Featured"
        case enabled = "Enabled"
        case favorites = "Favorites"
        case all = "All Capabilities"
        case custom = "My Actions"
        var id: Self { self }
    }
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
    var isRunning = false
    var resultMode = ResultMode.output
    var errorMessage: String?
    var searchText = ""
    var scope = Scope.featured
    var category: CapabilityCategory?
    private let store: RecipeStore

    init(store: RecipeStore = RecipeStore()) {
        self.store = store
        recipes = store.load()
        selection = recipes.first?.id
        synchronizeTestSelection()
    }

    var selectedIndex: Int? { selection.flatMap { id in recipes.firstIndex { $0.id == id } } }

    var visibleRecipes: [Recipe] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return recipes.filter { recipe in
            let inScope: Bool
            if let category {
                inScope = recipe.category == category.rawValue
            } else {
                inScope = switch scope {
                case .featured: recipe.isFeatured
                case .enabled: recipe.isEnabled
                case .favorites: recipe.isFavorite
                case .all: true
                case .custom: recipe.kind == .javascript || recipe.kind == .model
                }
            }
            return inScope && (query.isEmpty || recipe.name.localizedCaseInsensitiveContains(query) || recipe.summary.localizedCaseInsensitiveContains(query) || recipe.category.localizedCaseInsensitiveContains(query))
        }
    }

    var enabledCount: Int { recipes.count(where: \.isEnabled) }
    var builtinCount: Int { recipes.count { $0.kind == .builtin || $0.kind == .composed } }

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
        let category = template.kind == .model ? "Model Actions" : "Custom Scripts"
        let recipe = Recipe(name: template.name, summary: template.summary, kind: template.kind, source: template.source, isEnabled: false, version: template.version, applicability: template.applicability, parameters: template.parameters, testCases: template.testCases, category: category, modelConfiguration: template.modelConfiguration)
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
            },
            category: original.kind == .model ? "Model Actions" : "Custom Scripts",
            modelConfiguration: original.modelConfiguration
        )
        recipes.append(copy)
        selection = copy.id
        testSelection = copy.testCases.first?.id
        save()
    }

    func copyBuiltinToScript() {
        guard let selectedIndex else { return }
        let original = recipes[selectedIndex]
        guard original.kind != .javascript else { duplicateSelection(); return }
        let testCases = original.testCases.map { RecipeTestCase(name: $0.name, input: $0.input, selections: $0.selections, expectedOutput: $0.expectedOutput, expectedError: $0.expectedError) }
        let copy = Recipe(name: original.name + " Script", summary: "Custom copy of \(original.name)", kind: .javascript, source: BuiltinRecipes.scriptSource(for: original), isEnabled: false, parameters: original.parameters, testCases: testCases, category: "Custom Scripts")
        recipes.append(copy)
        selection = copy.id
        testSelection = copy.testCases.first?.id
        scope = .custom
        category = nil
        save()
    }

    func toggleEnabled(_ id: Recipe.ID) {
        guard let index = recipes.firstIndex(where: { $0.id == id }) else { return }
        recipes[index].isEnabled.toggle()
        save()
    }

    func toggleFavorite(_ id: Recipe.ID) {
        guard let index = recipes.firstIndex(where: { $0.id == id }) else { return }
        recipes[index].isFavorite.toggle()
        save()
    }

    func moveVisible(from offsets: IndexSet, to destination: Int) {
        let visible = visibleRecipes
        guard destination <= visible.count else { return }
        let movingIDs = offsets.map { visible[$0].id }
        let targetID = destination < visible.count ? visible[destination].id : nil
        let moving = recipes.filter { movingIDs.contains($0.id) }
        recipes.removeAll { movingIDs.contains($0.id) }
        let targetIndex = targetID.flatMap { id in recipes.firstIndex { $0.id == id } } ?? recipes.endIndex
        recipes.insert(contentsOf: moving, at: targetIndex)
        save()
    }

    func assignShortcut(_ shortcut: String?, to id: Recipe.ID) {
        guard let index = recipes.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = shortcut?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let cleaned, !cleaned.isEmpty, recipes.contains(where: { $0.id != id && $0.keyboardShortcut == cleaned }) {
            errorMessage = "That shortcut is already assigned to another action."
            return
        }
        recipes[index].keyboardShortcut = cleaned?.isEmpty == false ? cleaned : nil
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
                    testCases: recipe.testCases,
                    category: recipe.kind == .model ? "Model Actions" : "Custom Scripts",
                    modelConfiguration: recipe.modelConfiguration
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
            let exportable = recipes.filter { $0.kind == .javascript || $0.kind == .model }
            return RecipeArchiveDocument(data: try RecipeArchive(recipes: exportable).encoded())
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteSelection() {
        guard let selectedIndex, recipes[selectedIndex].kind == .javascript || recipes[selectedIndex].kind == .model else { return }
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
        if recipe.kind == .model {
            isRunning = true
            Task {
                execution = await AsyncRecipeRunner().execute(
                    ExecutionRequest(text: test.input, selections: test.selections),
                    recipe: recipe
                )
                resultMode = execution?.diagnostic == nil ? .output : .console
                isRunning = false
            }
            return
        }
        execution = RecipeRunner().execute(
            ExecutionRequest(text: test.input, selections: test.selections),
            recipe: recipe
        )
        resultMode = execution?.diagnostic == nil ? .output : .console
    }

    func runAll() {
        guard let selectedIndex else { return }
        let recipe = recipes[selectedIndex]
        if recipe.kind == .model {
            isRunning = true
            Task {
                var collected: [RecipeTestResult] = []
                for testCase in recipe.testCases {
                    let execution = await AsyncRecipeRunner().execute(
                        ExecutionRequest(text: testCase.input, selections: testCase.selections),
                        recipe: recipe
                    )
                    collected.append(RecipeTestResult(testCase: testCase, execution: execution))
                }
                testResults = collected
                if let selectedTestIndex { execution = collected.first { $0.id == recipe.testCases[selectedTestIndex].id }?.execution }
                resultMode = .console
                isRunning = false
            }
            return
        }
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
        guard let selectedIndex, recipes[selectedIndex].kind == .javascript || recipes[selectedIndex].kind == .model else { return false }
        guard !recipes[selectedIndex].testCases.isEmpty else {
            errorMessage = "Add at least one test case before enabling this action in Xcode."
            return false
        }
        if recipes[selectedIndex].kind == .model {
            let recipe = recipes[selectedIndex]
            isRunning = true
            Task {
                var collected: [RecipeTestResult] = []
                for testCase in recipe.testCases {
                    let result = await AsyncRecipeRunner().execute(
                        ExecutionRequest(text: testCase.input, selections: testCase.selections),
                        recipe: recipe
                    )
                    collected.append(RecipeTestResult(testCase: testCase, execution: result))
                }
                testResults = collected
                if collected.allSatisfy(\.passed), let currentIndex = recipes.firstIndex(where: { $0.id == recipe.id }) {
                    recipes[currentIndex].isEnabled = true
                    save()
                } else {
                    errorMessage = "Review the model output and update every expected snapshot before enabling this action in Xcode."
                }
                isRunning = false
            }
            return true
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
