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

            if recipe.source == "wrap-selection" {
                SwiftUI.Section("Wrapping") {
                    TextField("Prefix", text: parameterBinding("prefix"))
                    TextField("Suffix", text: parameterBinding("suffix"))
                }
            } else if recipe.source == "regex-replace" {
                SwiftUI.Section("Replacement") {
                    TextField("Pattern", text: parameterBinding("pattern"))
                    TextField("Replacement", text: parameterBinding("replacement"))
                }
            }
        }
        .formStyle(.grouped)
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
