import SwiftUI
import EditSmithCore

struct RecipeInspector: View {
    enum Section: String, CaseIterable, Identifiable {
        case settings = "Settings"
        case api = "API"
        var id: Self { self }
    }

    @Binding var recipe: Recipe
    @Binding var selection: Section
    let library: RecipeLibrary

    var body: some View {
        VStack(spacing: 0) {
            if recipe.kind == .javascript {
                Picker("Inspector", selection: $selection) {
                    ForEach(availableSections) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(12)
            } else {
                Label("Action Settings", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }

            Divider()

            switch selection {
            case .settings:
                settings
            case .api:
                ScriptReferenceView(source: $recipe.source)
            }
        }
        .background(.background)
    }

    private var availableSections: [Section] {
        recipe.kind == .javascript ? Section.allCases : [.settings]
    }

    private var settings: some View {
        Form {
            SwiftUI.Section("Action") {
                TextField("Name", text: $recipe.name)
                TextField("Description", text: $recipe.summary, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Available in Xcode", isOn: $recipe.isEnabled)
                Toggle("Favorite", isOn: $recipe.isFavorite)
                TextField("Keyboard shortcut", text: shortcutBinding, prompt: Text("e.g. j"))
                Stepper("Version \(recipe.version)", value: $recipe.version, in: 1...999)
            }

            SwiftUI.Section("Availability") {
                Toggle("Requires a selection", isOn: $recipe.applicability.requiresSelection)
                TextField("File type UTIs", text: fileTypesBinding, axis: .vertical)
                    .lineLimit(2...3)
                Text("Separate multiple UTIs with commas. Leave empty to allow any file type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let descriptor = BuiltinRecipes.descriptor(for: recipe.id), !descriptor.options.isEmpty {
                SwiftUI.Section("Parameters") {
                    ForEach(descriptor.options) { option in
                        TextField(option.title, text: parameterBinding(option.id))
                    }
                }
            }

            if let descriptor = BuiltinRecipes.descriptor(for: recipe.id), let example = descriptor.examples.first {
                SwiftUI.Section("Example") {
                    LabeledContent("Input") {
                        Text(example.input).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                    LabeledContent("Output") {
                        Text(example.output).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutBinding: Binding<String> {
        Binding(
            get: { recipe.keyboardShortcut ?? "" },
            set: { library.assignShortcut($0, to: recipe.id) }
        )
    }

    private var fileTypesBinding: Binding<String> {
        Binding(
            get: { recipe.applicability.fileTypes.joined(separator: ", ") },
            set: { value in
                recipe.applicability.fileTypes = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private func parameterBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { recipe.parameters[key] ?? "" },
            set: { recipe.parameters[key] = $0 }
        )
    }
}
