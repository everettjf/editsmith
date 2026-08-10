import Foundation
import Testing
@testable import JSPowerCore

@Suite("Recipe engine")
struct RecipeEngineTests {
    @Test @MainActor func builtinsTransformText() throws {
        let engine = RecipeEngine()
        #expect(try engine.run(BuiltinRecipes.all[0], input: "z\na") == "a\nz")
        #expect(try engine.run(BuiltinRecipes.all[1], input: "a  \nb\t") == "a\nb")
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
        let suite = "JSPowerCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecipeStore(defaults: defaults)
        let recipes = [Recipe(name: "One", summary: "Test", kind: .builtin, source: "uppercase")]
        try store.save(recipes)
        #expect(store.load() == recipes)
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
