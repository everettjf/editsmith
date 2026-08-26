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

            if recipe.kind == .model {
                SwiftUI.Section("Model Provider") {
                    Picker("Provider", selection: modelProviderBinding) {
                        ForEach(ModelRecipeConfiguration.Provider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    if modelProviderBinding.wrappedValue == .ollama {
                        TextField("Model", text: modelNameBinding, prompt: Text("llama3.2"))
                        TextField("Endpoint", text: modelEndpointBinding, prompt: Text("http://127.0.0.1:11434"))
                    } else if modelProviderBinding.wrappedValue == .applePrivateCloud {
                        Label("Requires macOS 27, an eligible developer account, and Apple's PCC entitlement.", systemImage: "cloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Runs privately on this Mac with Apple Intelligence and works offline.", systemImage: "apple.intelligence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Instructions", text: modelInstructionsBinding, axis: .vertical)
                        .lineLimit(3...6)
                }
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

    private var modelProviderBinding: Binding<ModelRecipeConfiguration.Provider> {
        Binding(
            get: { recipe.modelConfiguration?.provider ?? .appleOnDevice },
            set: { provider in
                ensureModelConfiguration()
                recipe.modelConfiguration?.provider = provider
            }
        )
    }

    private var modelNameBinding: Binding<String> {
        Binding(get: { recipe.modelConfiguration?.modelName ?? "llama3.2" }, set: { ensureModelConfiguration(); recipe.modelConfiguration?.modelName = $0 })
    }

    private var modelEndpointBinding: Binding<String> {
        Binding(get: { recipe.modelConfiguration?.endpoint ?? "http://127.0.0.1:11434" }, set: { ensureModelConfiguration(); recipe.modelConfiguration?.endpoint = $0 })
    }

    private var modelInstructionsBinding: Binding<String> {
        Binding(get: { recipe.modelConfiguration?.instructions ?? "" }, set: { ensureModelConfiguration(); recipe.modelConfiguration?.instructions = $0 })
    }

    private func ensureModelConfiguration() {
        if recipe.modelConfiguration == nil { recipe.modelConfiguration = .init() }
    }
}
