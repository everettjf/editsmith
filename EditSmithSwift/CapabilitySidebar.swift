import SwiftUI
import EditSmithCore

struct CapabilitySidebar: View {
    let library: RecipeLibrary

    var body: some View {
        @Bindable var library = library

        VStack(spacing: 0) {
            LibrarySummary(enabled: library.enabledCount, total: library.builtinCount)
            Divider()
            scopePicker
            Divider()
            capabilityList
        }
        .searchable(text: $library.searchText, placement: .sidebar, prompt: "Search 80+ capabilities")
        .navigationTitle("Capabilities")
        .navigationSplitViewColumnWidth(min: 260, ideal: 310, max: 380)
    }

    private var scopePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(RecipeLibrary.Scope.allCases) { scope in
                    Button(scope.rawValue) {
                        library.scope = scope
                        library.category = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(library.category == nil && library.scope == scope ? .accentColor : .secondary)
                }
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
    }

    private var capabilityList: some View {
        List(selection: selectionBinding) {
            Section("Categories") {
                ForEach(CapabilityCategory.allCases) { category in
                    Button {
                        library.category = category
                    } label: {
                        HStack {
                            Label(category.rawValue, systemImage: icon(category))
                            Spacer()
                            Text("\(count(category))").foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section(listTitle) {
                ForEach(library.visibleRecipes) { recipe in
                    CapabilityRow(
                        recipe: recipe,
                        onToggleEnabled: { library.toggleEnabled(recipe.id) },
                        onToggleFavorite: { library.toggleFavorite(recipe.id) }
                    )
                    .tag(recipe.id)
                }
                .onMove(perform: library.moveVisible)
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if library.visibleRecipes.isEmpty {
                ContentUnavailableView.search(text: library.searchText)
            }
        }
    }

    private var selectionBinding: Binding<Recipe.ID?> {
        Binding(get: { library.selection }, set: { library.selection = $0 })
    }

    private var listTitle: String {
        if let category = library.category { return category.rawValue }
        return library.scope.rawValue
    }

    private func count(_ category: CapabilityCategory) -> Int {
        library.recipes.count { $0.category == category.rawValue }
    }

    private func icon(_ category: CapabilityCategory) -> String {
        BuiltinRecipes.descriptors.first { $0.recipe.category == category.rawValue }?.systemImage ?? "square.grid.2x2"
    }
}

private struct LibrarySummary: View {
    let enabled: Int
    let total: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("EditSmith Library").font(.headline)
                Text("\(enabled) enabled · \(total) built in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }
}

private struct CapabilityRow: View {
    let recipe: Recipe
    let onToggleEnabled: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(recipe.name).font(.body.weight(.medium)).lineLimit(1)
                    if recipe.isFeatured {
                        Image(systemName: "sparkles").foregroundStyle(.orange).accessibilityLabel("Featured")
                    }
                }
                Text(recipe.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button("Favorite", systemImage: recipe.isFavorite ? "star.fill" : "star", action: onToggleFavorite)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(recipe.isFavorite ? .yellow : .secondary)
            Button(recipe.isEnabled ? "Disable in Xcode" : "Enable in Xcode", systemImage: recipe.isEnabled ? "checkmark.circle.fill" : "circle", action: onToggleEnabled)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(recipe.isEnabled ? .green : .secondary)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
    }
}
