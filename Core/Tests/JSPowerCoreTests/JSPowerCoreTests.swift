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
}
