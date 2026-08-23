import Testing
import EditSmithCore

struct EditSmithCoreSmokeTests {
    @Test func builtinsAreUniquelyIdentified() {
        #expect(Set(BuiltinRecipes.all.map(\.id)).count == BuiltinRecipes.all.count)
        #expect(BuiltinRecipes.all.allSatisfy { !$0.name.isEmpty && $0.isEnabled })
    }
}
