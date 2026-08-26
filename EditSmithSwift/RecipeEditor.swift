import SwiftUI
import EditSmithCore

struct RecipeEditor: View {
    @Binding var recipe: Recipe
    let library: RecipeLibrary
    @State private var isShowingInspector = true
    @State private var inspectorSection = RecipeInspector.Section.settings
    @State private var issues: [ScriptIssue] = []

    var body: some View {
        @Bindable var library = library

        VStack(spacing: 0) {
            RecipeHeader(recipe: recipe)

            Divider()

            if let testIndex = library.selectedTestIndex {
                VSplitView {
                    primaryWorkspace

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            TestFixtureEditor(test: $recipe.testCases[testIndex], library: library)
                            Divider()
                            EditorPane(
                                title: "Expected Output",
                                systemImage: "checkmark.rectangle",
                                text: $recipe.testCases[testIndex].expectedOutput
                            )
                        }

                        VSplitView {
                            TestFixtureEditor(test: $recipe.testCases[testIndex], library: library)
                            EditorPane(
                                title: "Expected Output",
                                systemImage: "checkmark.rectangle",
                                text: $recipe.testCases[testIndex].expectedOutput
                            )
                        }
                    }
                    .frame(minHeight: 150, idealHeight: 190)

                    ResultInspector(
                        input: recipe.testCases[testIndex].input,
                        source: recipe.source,
                        execution: library.execution,
                        results: library.testResults,
                        mode: $library.resultMode,
                        isRunning: library.isRunning
                    )
                    .frame(minHeight: 140, idealHeight: 170)
                }
            } else {
                ContentUnavailableView {
                    Label("No test cases", systemImage: "checklist")
                } description: {
                    Text("Add a fixture to test this action before enabling it in Xcode.")
                } actions: {
                    Button("Add Test Case", action: library.addTest)
                }
            }
        }
        .frame(minWidth: 360, maxWidth: .infinity)
        .navigationTitle(recipe.name)
        .focusedSceneValue(\.recipeLibrary, library)
        .inspector(isPresented: $isShowingInspector) {
            RecipeInspector(recipe: $recipe, selection: $inspectorSection, library: library)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
        }
        .task(id: recipe.source) {
            guard recipe.kind == .javascript else { issues = []; return }
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            let source = recipe.source
            issues = await Task.detached(priority: .utility) { ScriptLinter.inspect(source) }.value
        }
        .toolbar {
            ControlGroup {
                Button("Run Test", systemImage: "play.fill", action: library.runCurrent)
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(library.selectedTestIndex == nil || library.isRunning)
                    .help("Run the selected test (⌘R)")
                Button("Run All", systemImage: "checkmark.circle", action: library.runAll)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(recipe.testCases.isEmpty || library.isRunning)
                    .help("Run every test (⇧⌘R)")
            }

            if recipe.kind == .javascript || recipe.kind == .model {
                Button("Test and Enable in Xcode", systemImage: "checkmark.seal") {
                    library.testAndEnableCurrent()
                }
                .disabled(recipe.testCases.isEmpty || library.isRunning || (recipe.kind == .javascript && issues.contains { $0.severity == .error }))
                .help("Run all tests and enable this action when they pass")
            }

            Button("Save", systemImage: "square.and.arrow.down", action: library.save)
                .keyboardShortcut("s", modifiers: [.command])
                .help("Save library changes (⌘S)")

            Menu("More", systemImage: "ellipsis.circle") {
                Button("Update Snapshot", systemImage: "arrow.triangle.2.circlepath", action: library.updateSnapshot)
                    .keyboardShortcut("u", modifiers: [.command, .option])
                    .disabled(library.execution == nil)
                if recipe.kind != .javascript {
                    Button("Copy as Script", systemImage: "doc.on.doc", action: library.copyBuiltinToScript)
                }
            }

            Button("Inspector", systemImage: "sidebar.trailing") {
                isShowingInspector.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .help("Show or hide the inspector (⌥⌘I)")
        }
    }

    @ViewBuilder
    private var primaryWorkspace: some View {
        if recipe.kind == .javascript {
            VStack(spacing: 0) {
                SourceEditorPane(title: "JavaScript", text: $recipe.source, isEditable: true)
                    .padding(10)
                ScriptIssuesBar(issues: issues)
            }
            .frame(minHeight: 210, idealHeight: 280)
        } else if recipe.kind == .model {
            ModelPromptEditor(prompt: $recipe.source)
                .padding(10)
                .frame(minHeight: 210, idealHeight: 280)
        } else {
            BuiltinActionSummary(recipe: recipe)
                .frame(minHeight: 108, idealHeight: 130, maxHeight: 160)
        }
    }
}
private struct RecipeHeader: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recipe.kind == .model ? "brain.head.profile" : (recipe.kind == .builtin ? "wand.and.stars" : "curlybraces"))
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name).font(.title3.weight(.semibold))
                Text(recipe.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            Label(
                recipe.isEnabled ? "Available in Xcode" : "Disabled",
                systemImage: recipe.isEnabled ? "checkmark.circle.fill" : "pause.circle"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(recipe.isEnabled ? .green : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct ModelPromptEditor: View {
    @Binding var prompt: String

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: "Model Prompt", systemImage: "brain.head.profile") {
                Text("{{input}} = Xcode selection")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: $prompt)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.background)
                .accessibilityLabel("Model prompt template")
        }
        .background(.background)
        .clipShape(.rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
    }
}

private struct BuiltinActionSummary: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 30))
                .foregroundStyle(.tint)
                .frame(width: 56, height: 56)
                .background(.tint.opacity(0.1), in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(recipe.kind == .composed ? "Composed transformation" : "Built-in transformation").font(.headline)
                    if recipe.isFeatured {
                        Label("Featured", systemImage: "sparkles").font(.caption).foregroundStyle(.orange)
                    }
                }
                Text(recipe.summary).foregroundStyle(.secondary)
                Text(recipe.kind == .composed ? "Runs a local pipeline of built-in capabilities" : "Implemented natively by EditSmith · No script editing required")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if !recipe.componentIDs.isEmpty {
                    Text(componentNames)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(18)
        .background(.background)
    }

    private var componentNames: String {
        recipe.componentIDs.compactMap { identifier in
            BuiltinRecipes.all.first { $0.id == identifier }?.name
        }.joined(separator: " → ")
    }
}

private struct TestFixtureEditor: View {
    @Binding var test: RecipeTestCase
    let library: RecipeLibrary

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: test.name, systemImage: "doc.text") {
                Menu("Test Cases", systemImage: "checklist") {
                    if let recipeIndex = library.selectedIndex {
                        ForEach(library.recipes[recipeIndex].testCases) { item in
                            Button(item.name) { library.selectTest(item.id) }
                        }
                    }
                    Divider()
                    Button("Add Test", systemImage: "plus", action: library.addTest)
                    Button("Delete Test", systemImage: "trash", role: .destructive, action: library.deleteTest)
                }
                .labelStyle(.iconOnly)
            }

            TextEditor(text: $test.input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)

            Divider()

            HStack(spacing: 8) {
                TextField("Expected error (optional)", text: expectedErrorBinding)
                    .textFieldStyle(.plain)

                Divider().frame(height: 16)

                Label(test.selections.isEmpty ? "Whole buffer" : "\(test.selections.count) selections", systemImage: "selection.pin.in.out")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Add Selection", systemImage: "plus", action: library.addSelectionRange)
                    .labelStyle(.iconOnly)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)

            if !test.selections.isEmpty {
                List {
                    ForEach($test.selections) { $selection in
                        SelectionEditor(selection: $selection)
                    }
                    .onDelete(perform: library.removeSelectionRange)
                }
                .frame(height: 72)
            }
        }
        .frame(minWidth: 180)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Xcode buffer test fixture")
    }

    private var expectedErrorBinding: Binding<String> {
        Binding(
            get: { test.expectedError ?? "" },
            set: { test.expectedError = $0.isEmpty ? nil : $0 }
        )
    }
}

private struct SelectionEditor: View {
    @Binding var selection: EditSmithCore.TextRange

    var body: some View {
        HStack(spacing: 5) {
            Text("L")
            TextField("Start line", value: $selection.start.line, format: .number).frame(width: 34)
            Text(":")
            TextField("Start column", value: $selection.start.column, format: .number).frame(width: 34)
            Text("→")
            TextField("End line", value: $selection.end.line, format: .number).frame(width: 34)
            Text(":")
            TextField("End column", value: $selection.end.column, format: .number).frame(width: 34)
        }
        .font(.system(.caption, design: .monospaced))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selection range")
    }
}

private struct EditorPane: View {
    let title: String
    let systemImage: String
    @Binding var text: String

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: title, systemImage: systemImage)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        }
        .frame(minWidth: 180)
    }
}

private struct PaneHeader<Actions: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let actions: Actions

    init(title: String, systemImage: String, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage).font(.headline)
            Spacer()
            actions
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}
