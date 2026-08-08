import SwiftUI
import Observation
import JSPowerCore

@MainActor @Observable
final class RecipeLibrary {
    var recipes: [Recipe]
    var selection: Recipe.ID?
    var testInput = "let greeting = \"hello\";"
    var testOutput = ""
    var errorMessage: String?
    private let store = RecipeStore()

    init() {
        recipes = store.load()
        selection = recipes.first?.id
    }

    var selectedIndex: Int? { selection.flatMap { id in recipes.firstIndex { $0.id == id } } }

    func addRecipe() {
        let recipe = Recipe(name: "New Recipe", summary: "Local JavaScript transformation", kind: .javascript, source: "function transform(input) {\n  return input;\n}")
        recipes.append(recipe)
        selection = recipe.id
        save()
    }

    func deleteSelection() {
        guard let selectedIndex, recipes[selectedIndex].kind == .javascript else { return }
        recipes.remove(at: selectedIndex)
        selection = recipes.first?.id
        save()
    }

    func save() {
        do { try store.save(recipes); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func run() {
        guard let selectedIndex else { return }
        do { testOutput = try RecipeEngine().run(recipes[selectedIndex], input: testInput); errorMessage = nil }
        catch { testOutput = ""; errorMessage = error.localizedDescription }
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
                Button("Add Recipe", systemImage: "plus") { library.addRecipe() }
                Button("Delete Recipe", systemImage: "trash", role: .destructive) { library.deleteSelection() }
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
        .alert("Recipe Error", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(library.errorMessage ?? "") }
    }
}

private struct RecipeEditor: View {
    @Binding var recipe: Recipe
    let library: RecipeLibrary

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $recipe.name)
                TextField("Description", text: $recipe.summary)
                Toggle("Enabled in Xcode", isOn: $recipe.isEnabled)
            }
            .formStyle(.grouped)
            .frame(height: 150)

            HSplitView {
                editorPane(title: recipe.kind == .builtin ? "Built-in action" : "JavaScript", text: $recipe.source, editable: recipe.kind == .javascript)
                editorPane(title: "Sample Input", text: Binding(get: { library.testInput }, set: { library.testInput = $0 }), editable: true)
                editorPane(title: "Output", text: Binding(get: { library.testOutput }, set: { _ in }), editable: false)
            }
        }
        .navigationTitle(recipe.name)
        .toolbar {
            Button("Run", systemImage: "play.fill") { library.run() }.keyboardShortcut("r", modifiers: [.command])
            Button("Save", systemImage: "square.and.arrow.down") { library.save() }.keyboardShortcut("s", modifiers: [.command])
        }
    }

    private func editorPane(title: String, text: Binding<String>, editable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).padding(.horizontal)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .disabled(!editable)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary, in: .rect(cornerRadius: 8))
                .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 250)
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
                Text("Recipes and sample text stay on this Mac. JavaScript recipes receive only the text Xcode passes to the extension.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 300)
    }
}
