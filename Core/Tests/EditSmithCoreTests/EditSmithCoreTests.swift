import Foundation
import Testing
@testable import EditSmithCore

@Suite("Recipe engine")
struct RecipeEngineTests {
    @Test func extensionSafetyPreferencesRoundTripPreview() {
        let suite = "EditSmithSafetyTests.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var preferences = ExtensionPreferences(defaults: defaults); preferences.dryRun = true
        preferences.lastSnapshot = .init(recipeName: "Uppercase", before: "a", after: "A")
        #expect(preferences.dryRun)
        #expect(preferences.lastSnapshot?.after == "A")
    }
    @Test @MainActor func builtinsTransformText() throws {
        let engine = RecipeEngine()
        let recipes = Dictionary(uniqueKeysWithValues: BuiltinRecipes.all.map { ($0.source, $0) })
        #expect(try engine.run(recipes["sort-lines"]!, input: "z\na") == "a\nz")
        #expect(try engine.run(recipes["trim-lines"]!, input: "a  \nb\t") == "a\nb")
    }

    @Test @MainActor func javascriptTransformRunsLocally() throws {
        let recipe = Recipe(name: "Wrap", summary: "", kind: .javascript, source: "function transform(input) { return '<' + input + '>'; }")
        #expect(try RecipeEngine().run(recipe, input: "code") == "<code>")
    }

    @Test @MainActor func javascriptErrorsAreReported() {
        let recipe = Recipe(name: "Bad", summary: "", kind: .javascript, source: "function transform(input) { throw new Error('boom'); }")
        #expect(throws: RecipeError.self) { try RecipeEngine().run(recipe, input: "code") }
    }

    @Test func storeRoundTripsRecipes() throws {
        let suite = "EditSmithCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let scriptsDirectory = FileManager.default.temporaryDirectory
            .appending(path: "EditSmithCoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scriptsDirectory) }
        let store = RecipeStore(defaults: defaults, scriptsDirectoryURL: scriptsDirectory)
        let custom = Recipe(name: "One", summary: "Test", kind: .javascript, source: "function transform(input) { return input; }")
        let recipes = BuiltinRecipes.all + [custom]
        try store.save(recipes)
        let loaded = store.load()
        #expect(loaded.last == custom)
        #expect(loaded.filter { $0.kind != .javascript }.map(\.id) == BuiltinRecipes.all.map(\.id))
        let storedFiles = try FileManager.default.contentsOfDirectory(atPath: scriptsDirectory.path)
        #expect(storedFiles.count == 1)
        #expect(defaults.data(forKey: "swift.recipes.v2") == nil)
    }

    @Test func modelRecipesRoundTripWithProviderConfiguration() throws {
        let recipe = Recipe(
            name: "Explain Code",
            summary: "Model example",
            kind: .model,
            source: "Explain this code:\n\n{{input}}",
            isEnabled: false,
            modelConfiguration: .init(provider: .ollama, modelName: "llama3.2", endpoint: "http://127.0.0.1:11434")
        )
        let decoded = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
        #expect(decoded == recipe)
        #expect(decoded.modelConfiguration?.provider == .ollama)
    }

    @Test func legacyCatalogMigratesWithoutDuplicateBuiltins() throws {
        let suite = "EditSmithCatalogMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = [
            Recipe(id: "builtin.sort-lines", name: "Sort Lines", summary: "", kind: .builtin, source: "sort-lines", isEnabled: true),
            Recipe(id: "builtin.remove-duplicates", name: "Old Duplicate", summary: "", kind: .builtin, source: "remove-duplicate-lines", isEnabled: true),
        ]
        defaults.set(try JSONEncoder().encode(legacy), forKey: "swift.recipes.v2")
        let scriptsDirectory = FileManager.default.temporaryDirectory
            .appending(path: "EditSmithCatalogMigration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scriptsDirectory) }
        let store = RecipeStore(defaults: defaults, scriptsDirectoryURL: scriptsDirectory)
        let migrated = store.load()
        #expect(migrated.filter { $0.kind != .javascript }.count == BuiltinRecipes.all.count)
        #expect(migrated.filter(\.isEnabled).count == 10)
        #expect(!migrated.contains { $0.id == "builtin.remove-duplicates" })
        #expect(store.load().filter(\.isEnabled).count == 10)
    }

    @Test func legacyCustomScriptsMigrateToFilesAndCanBeDeleted() throws {
        let suite = "EditSmithScriptMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let scriptsDirectory = FileManager.default.temporaryDirectory
            .appending(path: "EditSmithScriptMigration-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scriptsDirectory) }
        let custom = Recipe(
            name: "Migrated Script",
            summary: "",
            kind: .javascript,
            source: "function transform(input) { return input; }"
        )
        defaults.set(try JSONEncoder().encode(BuiltinRecipes.all + [custom]), forKey: "swift.recipes.v2")

        let store = RecipeStore(defaults: defaults, scriptsDirectoryURL: scriptsDirectory)
        #expect(store.load().contains { $0.id == custom.id })
        #expect(defaults.data(forKey: "swift.recipes.v2") == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: scriptsDirectory.path).count == 1)

        try store.save(BuiltinRecipes.all)
        #expect(!store.load().contains { $0.id == custom.id })
        #expect(try FileManager.default.contentsOfDirectory(atPath: scriptsDirectory.path).isEmpty)
    }

    @Test func recipeArchiveRoundTripsAndRejectsInvalidInput() throws {
        let recipe = Recipe(
            name: "Wrap",
            summary: "Test",
            kind: .javascript,
            source: "function transform(input) { return input; }",
            version: 3,
            applicability: .init(fileTypes: ["public.swift-source"], requiresSelection: true),
            parameters: ["prefix": "("]
        )
        let data = try RecipeArchive(recipes: [recipe]).encoded()
        let decoded = try RecipeArchive.decode(data)
        #expect(decoded.recipes == [recipe])

        let future = try RecipeArchive(formatVersion: 99, recipes: [recipe]).encoded()
        #expect(throws: RecipeArchiveError.unsupportedFormat(99)) { try RecipeArchive.decode(future) }
        let empty = try RecipeArchive(recipes: []).encoded()
        #expect(throws: RecipeArchiveError.emptyArchive) { try RecipeArchive.decode(empty) }

        let unsafe = Recipe(name: "Unsafe", summary: "", kind: .javascript, source: "function transform(input) { return eval(input); }")
        #expect(throws: RecipeArchiveError.unsafeRecipe) {
            try RecipeArchive.decode(RecipeArchive(recipes: [unsafe]).encoded())
        }
    }

    @Test func catalogHasEightyCapabilitiesAndTenDefaults() {
        #expect(BuiltinRecipes.all.count >= 80)
        #expect(BuiltinRecipes.all.filter(\.isEnabled).count == 10)
        #expect(BuiltinRecipes.featured.count >= 10)
        #expect(Set(BuiltinRecipes.all.map(\.id)).count == BuiltinRecipes.all.count)
        #expect(Set(BuiltinRecipes.all.map(\.source)).count == BuiltinRecipes.all.count)
        #expect(CapabilityCategory.allCases.allSatisfy { category in
            BuiltinRecipes.all.contains { $0.category == category.rawValue }
        })
    }

    @Test @MainActor func deterministicBuiltinExamplesPass() {
        for recipe in BuiltinRecipes.all where !recipe.testCases.isEmpty {
            let results = RecipeTestRunner().runAll(recipe: recipe)
            #expect(results.allSatisfy { $0.passed }, "Built-in example failed: \(recipe.name)")
        }
    }

    @Test @MainActor func composedCapabilityRunsItsPipeline() throws {
        let composed = BuiltinRecipes.all.first { $0.kind == .composed }!
        #expect(try RecipeEngine().run(composed, input: " b \n\na\nb ") == "a\nb")
    }

    @Test @MainActor func selectedRangesAreTransformedWithoutTouchingOtherText() throws {
        let recipe = Recipe(name: "Upper", summary: "", kind: .builtin, source: "uppercase")
        let lines = ["let one = alpha\n", "let two = beta\n"]
        let ranges = [
            TextRange(start: .init(line: 0, column: 10), end: .init(line: 0, column: 15)),
            TextRange(start: .init(line: 1, column: 10), end: .init(line: 1, column: 14)),
        ]
        let result = try TextBufferTransformer().transform(lines: lines, ranges: ranges, recipe: recipe)
        #expect(result == ["let one = ALPHA\n", "let two = BETA\n"])
    }

    @Test @MainActor func everyBuiltinHasExpectedBehavior() throws {
        let recipes = Dictionary(uniqueKeysWithValues: BuiltinRecipes.all.map { ($0.source, $0) })
        #expect(try RecipeEngine().run(recipes["uppercase"]!, input: "Abc") == "ABC")
        #expect(try RecipeEngine().run(recipes["lowercase"]!, input: "AbC") == "abc")
        #expect(try RecipeEngine().run(recipes["pretty-json"]!, input: #"{"z":1,"a":2}"#) == "{\n  \"a\" : 2,\n  \"z\" : 1\n}")
        #expect(try RecipeEngine().run(recipes["remove-duplicate-lines"]!, input: "a\nb\na") == "a\nb")
        #expect(try RecipeEngine().run(recipes["regex-replace"]!, input: "a  \nb\t") == "a\nb")
    }

    @Test @MainActor func builtinsSupportCommentsAndParameterizedWrapping() throws {
        let recipes = Dictionary(uniqueKeysWithValues: BuiltinRecipes.all.map { ($0.source, $0) })
        let selection = TextRange(start: .init(line: 0, column: 0), end: .init(line: 0, column: 5))
        let commented = RecipeRunner().execute(
            ExecutionRequest(text: "value", selections: [selection]),
            recipe: recipes["toggle-line-comment"]!
        )
        #expect(commented.outputText == "// value")
        let uncommentedSelection = TextRange(start: .init(line: 0, column: 0), end: .init(line: 0, column: 8))
        let uncommented = RecipeRunner().execute(
            ExecutionRequest(text: commented.outputText, selections: [uncommentedSelection]),
            recipe: recipes["toggle-line-comment"]!
        )
        #expect(uncommented.outputText == "value")
        let wrapped = RecipeRunner().execute(
            ExecutionRequest(text: "value", selections: [selection]),
            recipe: recipes["wrap-selection"]!
        )
        #expect(wrapped.outputText == "(value)")
    }

    @Test @MainActor func applicabilityAndOutputLimitsAreEnforced() {
        let selectionOnly = Recipe(
            name: "Selection",
            summary: "",
            kind: .builtin,
            source: "uppercase",
            applicability: .init(fileTypes: ["public.swift-source"], requiresSelection: true)
        )
        let noSelection = RecipeRunner().execute(ExecutionRequest(text: "value"), recipe: selectionOnly)
        #expect(noSelection.diagnostic?.message == RecipeError.notApplicable.localizedDescription)

        let huge = Recipe(
            name: "Huge output",
            summary: "",
            kind: .javascript,
            source: "function transform(input) { return 'x'.repeat(5 * 1024 * 1024 + 1); }"
        )
        let result = RecipeRunner().execute(ExecutionRequest(text: "x"), recipe: huge)
        #expect(result.diagnostic?.message == RecipeError.outputTooLarge.localizedDescription)
    }

    @Test func legacyRecipesDefaultVersionApplicabilityAndParameters() throws {
        let data = #"{"id":"legacy","name":"Legacy","summary":"","kind":"builtin","source":"uppercase","isEnabled":true}"#.data(using: .utf8)!
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        #expect(recipe.version == 1)
        #expect(recipe.applicability == .init())
        #expect(recipe.parameters.isEmpty)
    }

    @Test @MainActor func malformedJavaScriptContractsAreRejected() {
        let missing = Recipe(name: "Missing", summary: "", kind: .javascript, source: "const value = 1;")
        let nonString = Recipe(name: "Number", summary: "", kind: .javascript, source: "function transform(input) { return 42; }")
        #expect(throws: RecipeError.self) { try RecipeEngine().run(missing, input: "x") }
        #expect(throws: RecipeError.invalidResult) { try RecipeEngine().run(nonString, input: "x") }
    }

    @Test @MainActor func safetyLimitsAreEnforced() {
        let identity = Recipe(name: "Identity", summary: "", kind: .javascript, source: "function transform(input) { return input; }")
        let oversizedScript = Recipe(name: "Huge", summary: "", kind: .javascript, source: String(repeating: " ", count: 256 * 1_024 + 1))
        #expect(throws: RecipeError.inputTooLarge) {
            try RecipeEngine().run(identity, input: String(repeating: "x", count: 5 * 1_024 * 1_024 + 1))
        }
        #expect(throws: RecipeError.scriptTooLarge) { try RecipeEngine().run(oversizedScript, input: "x") }
    }

    @Test @MainActor func runawayJavaScriptIsTerminated() {
        let runaway = Recipe(
            name: "Runaway",
            summary: "",
            kind: .javascript,
            source: "function transform(input) { while (true) {} }"
        )
        let started = ContinuousClock.now
        let result = RecipeRunner().execute(ExecutionRequest(text: "x"), recipe: runaway)
        #expect(result.diagnostic?.message == RecipeError.executionTimedOut.localizedDescription)
        #expect(started.duration(to: .now) < .seconds(2))
    }

    @Test @MainActor func wholeBufferAndCRLFLinesArePreserved() throws {
        let upper = Recipe(name: "Upper", summary: "", kind: .builtin, source: "uppercase")
        #expect(try TextBufferTransformer().transform(lines: ["a\r\n", "b\r\n"], ranges: [], recipe: upper) == ["A\r\n", "B\r\n"])
    }

    @Test @MainActor func executionCapturesConsoleAndEnvironment() {
        let recipe = Recipe(
            name: "Inspect",
            summary: "",
            kind: .javascript,
            source: "function transform(input) { console.log('file', environment.fileName, input.length); return input.toUpperCase(); }"
        )
        let result = RecipeRunner().execute(
            ExecutionRequest(text: "hello", fileName: "Sample.swift", fileType: "public.swift-source", indentationWidth: 2),
            recipe: recipe
        )
        #expect(result.outputText == "HELLO")
        #expect(result.logs.count == 1)
        #expect(result.logs[0].message.contains("Sample.swift"))
        #expect(result.diagnostic == nil)
    }

    @Test @MainActor func executionReportsSourceLocationAndStack() {
        let recipe = Recipe(
            name: "Broken",
            summary: "",
            kind: .javascript,
            source: "function transform(input) {\n  const value = input;\n  throw new Error('precise boom');\n}"
        )
        let result = RecipeRunner().execute(ExecutionRequest(text: "x"), recipe: recipe)
        #expect(result.diagnostic?.message.contains("precise boom") == true)
        #expect(result.diagnostic?.line != nil)
        #expect(result.diagnostic?.stack?.contains("transform") == true)
    }

    @Test @MainActor func executionUsesXcodeStyleSelectionsAndUpdatesRanges() {
        let recipe = Recipe(name: "Wrap", summary: "", kind: .javascript, source: "function transform(input) { return '[' + input + ']'; }")
        let selections = [
            TextRange(start: .init(line: 0, column: 0), end: .init(line: 0, column: 3)),
            TextRange(start: .init(line: 1, column: 0), end: .init(line: 1, column: 3)),
        ]
        let result = RecipeRunner().execute(ExecutionRequest(text: "one\ntwo", selections: selections), recipe: recipe)
        #expect(result.outputText == "[one]\n[two]")
        #expect(result.outputSelections.map(\.end.column) == [5, 5])
    }

    @Test @MainActor func runAllEvaluatesOutputAndExpectedErrors() {
        let recipe = Recipe(
            name: "Suite",
            summary: "",
            kind: .javascript,
            source: "function transform(input) { if (input === 'bad') throw new Error('not allowed'); return input.toUpperCase(); }",
            testCases: [
                RecipeTestCase(name: "Success", input: "good", expectedOutput: "GOOD"),
                RecipeTestCase(name: "Expected failure", input: "bad", expectedError: "not allowed"),
                RecipeTestCase(name: "Mismatch", input: "small", expectedOutput: "WRONG"),
            ]
        )
        let results = RecipeTestRunner().runAll(recipe: recipe)
        #expect(results.map(\.passed) == [true, true, false])
    }

    @Test func legacyRecipesDecodeWithoutTestCases() throws {
        let data = #"{"id":"00000000-0000-0000-0000-000000000001","name":"Legacy","summary":"","kind":"javascript","source":"function transform(input) { return input; }"}"#.data(using: .utf8)!
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        #expect(recipe.testCases.isEmpty)
    }
}
