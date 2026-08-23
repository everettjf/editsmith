import Testing
import EditSmithCore

struct EditSmithCoreSmokeTests {
    @Test func builtinsAreUniquelyIdentified() {
        #expect(Set(BuiltinRecipes.all.map(\.id)).count == BuiltinRecipes.all.count)
        #expect(BuiltinRecipes.all.allSatisfy { !$0.name.isEmpty })
        #expect(BuiltinRecipes.all.filter(\.isEnabled).count == 10)
    }
}
