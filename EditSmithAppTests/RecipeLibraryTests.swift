import Foundation
import Testing
@testable import EditSmith
@testable import EditSmithCore

@Suite("Recipe workbench")
@MainActor
struct RecipeLibraryTests {
    @Test func createDuplicateAndDeleteUserActions() {
        withLibrary { library in
            let initialCount = library.recipes.count
            library.addRecipe()
            #expect(library.recipes.count == initialCount + 1)
            #expect(library.recipes.last?.kind == .javascript)

            library.duplicateSelection()
            #expect(library.recipes.count == initialCount + 2)
            #expect(library.recipes.last?.name == "New Recipe Copy")
            #expect(library.recipes.last?.isEnabled == false)

            library.deleteSelection()
            #expect(library.recipes.count == initialCount + 1)
        }
    }

    @Test func generatedDraftStartsDisabledAndTestable() {
        withLibrary { library in
            library.addGeneratedDraft(
                name: "Uppercase Draft",
                source: "function transform(input) { return input.toUpperCase(); }",
                prompt: "Uppercase the selection"
            )
            let draft = library.recipes.last
            #expect(draft?.isEnabled == false)
            #expect(draft?.testCases.count == 1)
            #expect(draft?.summary.contains("Uppercase the selection") == true)
        }
    }

    @Test func testAndEnableRequiresPassingFixtures() {
        withLibrary { library in
            library.addRecipe()
            #expect(library.testAndEnableCurrent())
            #expect(library.recipes[library.selectedIndex!].isEnabled)

            library.recipes[library.selectedIndex!].testCases[0].expectedOutput = "wrong"
            library.recipes[library.selectedIndex!].isEnabled = false
            #expect(!library.testAndEnableCurrent())
            #expect(!library.recipes[library.selectedIndex!].isEnabled)
        }
    }

    @Test func scriptLinterFindsContractAndDelimiterProblems() {
        #expect(ScriptLinter.inspect("const value = (1;").contains { $0.severity == .error })
        #expect(ScriptLinter.inspect("function transform(input) { return input; }").isEmpty)
        #expect(ScriptLinter.inspect("function transform(input) { return fetch(input); }").contains { $0.severity == .warning })
    }

    @Test func capabilityLibraryFiltersPersistsAndCopiesScripts() throws {
        try withLibrary { library in
            #expect(library.builtinCount >= 80)
            #expect(library.enabledCount == 10)
            library.scope = .featured
            #expect(!library.visibleRecipes.isEmpty)
            #expect(library.visibleRecipes.allSatisfy { $0.isFeatured })

            let builtin = try #require(library.recipes.first { $0.kind == .builtin })
            library.selection = builtin.id
            library.toggleFavorite(builtin.id)
            #expect(library.recipes.first { $0.id == builtin.id }?.isFavorite == true)
            library.copyBuiltinToScript()
            #expect(library.recipes.last?.kind == .javascript)
            #expect(library.recipes.last?.isEnabled == false)
            #expect(library.recipes.last?.source.contains("function transform(input)") == true)
            library.runAll()
            #expect(library.testResults.allSatisfy { $0.passed })
        }
    }

    @Test func exportAndImportRoundTripDisablesImportedActions() throws {
        let suite = "EditSmithAppTests.Export.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let library = RecipeLibrary(store: RecipeStore(defaults: defaults))
        library.addRecipe()
        let document = try #require(library.exportDocument())
        let archive = try RecipeArchive.decode(document.data)
        #expect(archive.recipes.count == 1)

        let destinationSuite = "EditSmithAppTests.Import.\(UUID().uuidString)"
        let destinationDefaults = try #require(UserDefaults(suiteName: destinationSuite))
        defer { destinationDefaults.removePersistentDomain(forName: destinationSuite) }
        let destination = RecipeLibrary(store: RecipeStore(defaults: destinationDefaults))
        let url = FileManager.default.temporaryDirectory
            .appending(path: "EditSmith-\(UUID().uuidString).json")
        try document.data.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        destination.importArchive(from: url)
        let imported = try #require(destination.recipes.last)
        #expect(imported.kind == .javascript)
        #expect(imported.isEnabled == false)
        #expect(imported.id != archive.recipes[0].id)
    }

    private func withLibrary(_ body: (RecipeLibrary) throws -> Void) rethrows {
        let suite = "EditSmithAppTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(RecipeLibrary(store: RecipeStore(defaults: defaults)))
    }
}
